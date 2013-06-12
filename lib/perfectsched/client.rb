#
# PerfectSched
#
# Copyright (C) 2012-2013 Sadayuki Furuhashi
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
  class Client
    def initialize(config)
      @config = {}
      config.each_pair {|k,v| @config[k.to_sym] = v }

      @backend = Backend.new_backend(self, @config)

      @timezone = @config[:timezone] || 'UTC'
      @max_acquire = @config[:max_acquire] || 1
      @alive_time = @config[:alive_time] || 300
      @retry_wait = @config[:retry_wait] || 300  # TODO retry wait algorithm
    end

    attr_reader :backend
    attr_reader :config

    def init_database(options={})
      @backend.init_database(options)
    end

    def get_schedule_metadata(key, options={})
      @backend.get_schedule_metadata(key, options)
    end

    # :next_time => Time.now
    # :next_run_time => Time.now
    # :cron
    # :data
    # :delay => 0
    # :timezone => UTC
    def add(key, options={})
      cron = options[:cron]

      raise ArgumentError, ":cron option is required" unless cron

      delay = options[:delay] || 0
      timezone = options[:timezone] || @timezone

      next_time = options[:next_time] || Time.now.to_i
      next_time = PerfectSched.cron_time(cron, next_time.to_i, timezone)

      next_run_time = options[:next_run_time]
      if next_run_time
        next_run_time = next_run_time.to_i
      else
        next_run_time = next_time + delay
      end

      @backend.add(key, cron, delay, timezone, next_time, next_run_time, options)

      # TODO return value
      return next_time, next_run_time
    end

    def delete(key, options={})
      @backend.delete(key, options)
    end

    # :next_time => nil
    # :next_run_time => nil
    # :cron => nil
    # :delay => nil
    # :timezone => nil
    def modify(key, options={})
      @backend.modify(key, options)
    end

    def list(options={}, &block)
      @backend.list(options, &block)
    end

    # :now => Time.now
    # :max_acquire
    def acquire(options={})
      alive_time = options[:alive_time] || @alive_time
      max_acquire = options[:max_acquire] || 1

      @backend.acquire(alive_time, max_acquire, options)
    end

    def release(task_token, options={})
      alive_time = options[:alive_time] || @alive_time

      @backend.release(task_token, alive_time, options)
    end

    # :alive_time => nil
    def heartbeat(task_token, options={})
      alive_time = options[:alive_time] || @alive_time

      @backend.heartbeat(task_token, alive_time, options)
    end

    def retry(task_token, options={})
      alive_time = options[:retry_wait] || @retry_wait

      @backend.heartbeat(task_token, alive_time, options)
    end

    def finish(task_token, options={})
      @backend.finish(task_token, options)
    end

    def close
      @backend.close
    end
  end
end

