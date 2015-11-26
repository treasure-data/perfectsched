#
# PerfectSched
#
# Copyright (C) 2012 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

module PerfectSched
  module Backend
    class RDBCompatBackend
      include BackendHelper
      MAX_RETRY = 10

      class Token < Struct.new(:row_id, :scheduled_time, :cron, :delay, :timezone)
      end

      def initialize(client, config)
        super

        require 'sequel'
        url = config[:url]
        unless url
          raise ConfigError, "url option is required for the rdb_compat backend"
        end

        @table = config[:table]
        unless @table
          raise ConfigError, "table option is required for the rdb_compat backend"
        end

        #password = config[:password]
        #user = config[:user]

        case url.split('//',2)[0].to_s
        when /sqlite/i
          @db = Sequel.connect(url, :max_connections=>1)
        when /mysql/i
          require 'uri'

          uri = URI.parse(url)
          options = {
            user: uri.user,
            password: uri.password,
            host: uri.host,
            port: uri.port ? uri.port.to_i : 3306
          }
          options[:sslca] = config[:sslca] if config[:sslca]

          db_name = uri.path.split('/')[1]
          @db = Sequel.mysql2(db_name, options)
        else
          raise ConfigError, "'sqlite' and 'mysql' are supported"
        end

        @mutex = Mutex.new

        connect {
          # connection test
        }
      end

      MAX_SELECT_ROW = 4

      attr_reader :db

      def init_database(options)
        sql = %[
          CREATE TABLE IF NOT EXISTS `#{@table}` (
            id VARCHAR(255) NOT NULL,
            timeout INT NOT NULL,
            next_time INT NOT NULL,
            cron VARCHAR(128) NOT NULL,
            delay INT NOT NULL,
            data LONGBLOB NOT NULL,
            timezone VARCHAR(255) NULL,
            PRIMARY KEY (id)
          );]
        connect {
          @db.run sql
        }
      end

      def get_schedule_metadata(key, options={})
        connect {
          row = @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` WHERE id=? LIMIT 1", key).first
          unless row
            raise NotFoundError, "schedule key=#{key} does not exist"
          end
          attributes = create_attributes(row)
          return ScheduleMetadata.new(@client, key, attributes)
        }
      end

      def list(options, &block)
        connect {
          @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` ORDER BY timeout ASC") {|row|
            attributes = create_attributes(row)
            sched = ScheduleWithMetadata.new(@client, row[:id], attributes)
            yield sched
          }
        }
      end

      def add(key, type, cron, delay, timezone, data, next_time, next_run_time, options)
        data = data ? data.dup : {}
        data['type'] = type
        connect {
          begin
            n = @db["INSERT INTO `#{@table}` (id, timeout, next_time, cron, delay, data, timezone) VALUES (?, ?, ?, ?, ?, ?, ?);", key, next_run_time, next_time, cron, delay, data.to_json, timezone].insert
            return Schedule.new(@client, key)
          rescue Sequel::DatabaseError
            raise IdempotentAlreadyExistsError, "schedule key=#{key} already exists"
          end
        }
      end

      def delete(key, options)
        connect {
          n = @db["DELETE FROM `#{@table}` WHERE id=?;", key].delete
          if n <= 0
            raise IdempotentNotFoundError, "schedule key=#{key} does no exist"
          end
        }
      end

      def modify(key, options)
        ks = []
        vs = []
        [:cron, :delay, :timezone].each {|k|
          # TODO type and data are not supported
          if v = options[k]
            ks << k
            vs << v
          end
        }
        return nil if ks.empty?

        sql = "UPDATE `#{@table}` SET "
        sql << ks.map {|k| "#{k}=?" }.join(', ')
        sql << " WHERE id=?"

        args = [sql].concat(vs)
        args << key

        connect {
          n = @db[*args].update
          if n <= 0
            raise NotFoundError, "schedule key=#{key} does not exist"
          end
        }
      end

      def acquire(alive_time, max_acquire, options)
        now = (options[:now] || Time.now).to_i
        next_timeout = now + alive_time

        connect {
          while true
            rows = 0
            @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` WHERE timeout <= ? ORDER BY timeout ASC LIMIT #{MAX_SELECT_ROW};", now) {|row|

              n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=? AND timeout=?;", next_timeout, row[:id], row[:timeout]].update
              if n > 0
                scheduled_time = row[:next_time]
                attributes = create_attributes(row)
                task_token = Token.new(row[:id], row[:next_time], attributes[:cron], attributes[:delay], attributes[:timezone])
                task = Task.new(@client, row[:id], attributes, scheduled_time, task_token)
                return [task]
              end

              rows += 1
            }
            if rows < MAX_SELECT_ROW
              return nil
            end
          end
        }
      end

      def heartbeat(task_token, alive_time, options)
        now = (options[:now] || Time.now).to_i
        row_id = task_token.row_id
        scheduled_time = task_token.scheduled_time
        next_run_time = now + alive_time

        connect {
          n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=? AND next_time=?;", next_run_time, row_id, scheduled_time].update
          if n <= 0  # TODO fix
            row = @db.fetch("SELECT id, timeout, next_time FROM `#{@table}` WHERE id=? AND next_time=? LIMIT 1", row_id, scheduled_time).first
            if row == nil
              raise PreemptedError, "task #{task_token.inspect} does not exist or preempted."
            elsif row[:timeout] == next_run_time
              # ok
            else
              raise PreemptedError, "task time=#{Time.at(scheduled_time).utc} is preempted"
            end
          end
        }
      end

      def finish(task_token, options)
        row_id = task_token.row_id
        scheduled_time = task_token.scheduled_time
        next_time = PerfectSched.next_time(task_token.cron, scheduled_time, task_token.timezone)
        next_run_time = next_time + task_token.delay

        connect {
          n = @db["UPDATE `#{@table}` SET timeout=?, next_time=? WHERE id=? AND next_time=?;", next_run_time, next_time, row_id, scheduled_time].update
          if n <= 0
            raise IdempotentAlreadyFinishedError, "task time=#{Time.at(scheduled_time).utc} is already finished"
          end
        }
      end

      protected
      def connect(&block)
        @mutex.synchronize do
          retry_count = 0
          begin
            block.call
          rescue
            # workaround for "Mysql2::Error: Deadlock found when trying to get lock; try restarting transaction" error
            if $!.to_s.include?('try restarting transaction')
              err = ([$!] + $!.backtrace.map {|bt| "  #{bt}" }).join("\n")
              retry_count += 1
              if retry_count < MAX_RETRY
                STDERR.puts err + "\n  retrying."
                sleep 0.5
                retry
              else
                STDERR.puts err + "\n  abort."
              end
            end
            raise
          ensure
            @db.disconnect
          end
        end
      end

      def create_attributes(row)
        timezone = row[:timezone] || 'UTC'
        delay = row[:delay] || 0
        cron = row[:cron]
        next_time = row[:next_time]
        next_run_time = row[:timeout]

        d = row[:data]
        if d == nil || d == ''
          data = {}
        else
          begin
            data = JSON.parse(d)
          rescue
            data = {}
          end
        end

        type = data.delete('type')
        if type == nil || type.empty?
          type = row[:id].split(/\./, 2)[0]
        end

        attributes = {
          :timezone => timezone,
          :delay => delay,
          :cron => cron,
          :data => data,
          :next_time => next_time,
          :next_run_time => next_run_time,
          :type => type,
          :message => nil,  # not supported
          :node => nil,  # not supported
        }
      end

    end
  end
end

