
module PerfectSched


class RDBBackend < Backend
  def initialize(uri, table)
    super()
    require 'sequel'
    @uri = uri
    @table = table
    @db = Sequel.connect(@uri)
    init_db(@uri.split(':',2)[0])
  end

  private
  def init_db(type)
    sql = ''
    case type
    when /mysql/i
      sql << "CREATE TABLE IF NOT EXISTS `#{@table}` ("
      sql << "  id VARCHAR(256) NOT NULL,"
      sql << "  timeout INT NOT NULL,"
      sql << "  next_time INT NOT NULL,"
      sql << "  cron VARCHAR(128) NOT NULL,"
      sql << "  delay INT NOT NULL,"
      sql << "  data BLOB NOT NULL,"
      sql << "  PRIMARY KEY (id)"
      sql << ") ENGINE=INNODB;"
    else
      sql << "CREATE TABLE IF NOT EXISTS `#{@table}` ("
      sql << "  id VARCHAR(256) NOT NULL,"
      sql << "  timeout INT NOT NULL,"
      sql << "  next_time INT NOT NULL,"
      sql << "  cron VARCHAR(128) NOT NULL,"
      sql << "  delay INT NOT NULL,"
      sql << "  data BLOB NOT NULL,"
      sql << "  PRIMARY KEY (id)"
      sql << ");"
    end
    # TODO index
    connect {
      @db.run sql
    }
  end

  def connect(&block)
    begin
      block.call
    ensure
      @db.disconnect
    end
  end

  public
  def list(&block)
    @db.fetch("SELECT id, timeout, next_time, cron, delay, data FROM `#{@table}` ORDER BY timeout ASC") {|row|
      yield row[:id], row[:cron], row[:delay], row[:data], row[:next_time], row[:timeout]
    }
  end

  MAX_SELECT_ROW = 4

  def acquire(timeout, now=Time.now.to_i)
    connect {
      while true
        rows = 0
        @db.fetch("SELECT id, timeout, next_time, cron, delay, data FROM `#{@table}` WHERE timeout <= ? ORDER BY timeout ASC LIMIT #{MAX_SELECT_ROW};", now) {|row|

          n = @db["UPDATE `#{@table}` SET timeout=? WHERE id=? AND timeout=?;", timeout, row[:id], row[:timeout]].update
          salt = timeout
          if n > 0
            return [row[:id],salt], Task.new(row[:id], row[:next_time], row[:cron], row[:delay], row[:data])
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

  def add_checked(id, cron, delay, data, next_time, timeout)
    connect {
      begin
        n = @db["INSERT INTO `#{@table}` (id, timeout, next_time, cron, delay, data) VALUES (?, ?, ?, ?, ?, ?);", id, timeout, next_time, cron, delay, data].insert
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
      @db.fetch("SELECT id, timeout, next_time, cron, delay, data FROM `#{@table}` WHERE id=?;", id) {|row|
        return row[:cron], row[:delay], row[:data]
      }
      return nil
    }
  end

  def modify_checked(id, cron, delay, data)
    connect {
      n = @db["UPDATE `#{@table}` SET cron=?, delay=?, data=? WHERE id=?;", cron, delay, data, id].update
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

