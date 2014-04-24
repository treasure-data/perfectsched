
module PerfectSched


class RDBBackend < Backend
  def initialize(uri, table, config)
    super()
    require 'sequel'
    require 'uri'
    @uri = uri
    @table = table

    u = URI.parse(url)
    options = {
      max_connections: 1,
      user: u.user,
      password: u.password,
      host: u.host,
      port: u.port ? u.port.to_i : 3306
    }
    options[:sslca] = config[:sslca] if config[:sslca]
    @db = Sequel.mysql2(db_name, options)

    #init_db(@uri.split('//',2)[0])
    connect {
      # connection test
    }
  end

  def create_tables
    sql = ''
    sql << "CREATE TABLE IF NOT EXISTS `#{@table}` ("
    sql << "  id VARCHAR(256) NOT NULL,"
    sql << "  timeout INT NOT NULL,"
    sql << "  next_time INT NOT NULL,"
    sql << "  cron VARCHAR(128) NOT NULL,"
    sql << "  delay INT NOT NULL,"
    sql << "  data BLOB NOT NULL,"
    sql << "  timezone VARCHAR(256) NULL,"
    sql << "  PRIMARY KEY (id)"
    sql << ");"
    # TODO index
    connect {
      @db.run sql
    }
  end

  private
  def connect(&block)
    begin
      block.call
    ensure
      @db.disconnect
    end
  end

  public
  def list(&block)
    @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` ORDER BY timeout ASC") {|row|
      yield row[:id], row[:cron], row[:delay], row[:data], row[:next_time], row[:timeout], row[:timezone]
    }
  end

  MAX_SELECT_ROW = 4

  def acquire(timeout, now=Time.now.to_i)
    connect {
      while true
        rows = 0
        @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` WHERE timeout <= ? ORDER BY timeout ASC LIMIT #{MAX_SELECT_ROW};", now) {|row|

          n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=? AND timeout=?;", timeout, row[:id], row[:timeout]].update
          salt = timeout
          if n > 0
            return [row[:id],salt], Task.new(row[:id], row[:next_time], row[:cron], row[:delay], row[:data], row[:timezone])
          end

          rows += 1
        }
        if rows < MAX_SELECT_ROW
          return nil
        end
      end
    }
  end

  def finish(token, next_time, timeout)
    connect {
      id, salt = *token
      n = @db["UPDATE `#{@table}` SET timeout=?, next_time=? WHERE id=? AND timeout=?;", timeout, next_time, id, salt].update
      return n > 0
    }
  end

  def add_checked(id, cron, delay, data, next_time, timeout, timezone)
    connect {
      begin
        n = @db["INSERT INTO `#{@table}` (id, timeout, next_time, cron, delay, data, timezone) VALUES (?, ?, ?, ?, ?, ?, ?);", id, timeout, next_time, cron, delay, data, timezone].insert
        return true
      rescue Sequel::DatabaseError
        return nil
      end
    }
  end

  def delete(id)
    connect {
      n = @db["DELETE FROM `#{@table}` WHERE id=?;", id].delete
      return n > 0
    }
  end

  def get(id)
    connect {
      @db.fetch("SELECT id, timeout, next_time, cron, delay, data, timezone FROM `#{@table}` WHERE id=?;", id) {|row|
        return row[:cron], row[:delay], row[:data], row[:timezone], row[:next_time]
      }
      return nil
    }
  end

  def modify_checked(id, cron, delay, data, timezone)
    connect {
      n = @db["UPDATE `#{@table}` SET cron=?, delay=?, data=?, timezone=? WHERE id=?;", cron, delay, data, timezone, id].update
      return n > 0
    }
  end

  def modify_sched_checked(id, cron, delay)
    connect {
      n = @db["UPDATE `#{@table}` SET cron=?, delay=? WHERE id=?;", cron, delay, id].update
      return n > 0
    }
  end

  def modify_data_checked(id, data)
    connect {
      n = @db["UPDATE `#{@table}` SET data=? WHERE id=?;", data, id].update
      return n > 0
    }
  end

end


end

