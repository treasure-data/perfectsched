
module PerfectSched


class SimpleDBBackend < Backend
  def initialize(key_id, secret_key, domain)
    super()
    require 'aws-sdk'
    @consistent_read = false

    @db = AWS::SimpleDB.new(
      :access_key_id => key_id,
      :secret_access_key => secret_key)

    @domain_name = domain
    @domain = @db.domains[@domain_name]
    unless @domain.exists?
      @domain = @db.domains.create(@domain_name)
    end
  end

  attr_accessor :consistent_read

  def use_consistent_read(b=true)
    @consistent_read = b
    self
  end

  def list(&block)
    rows = 0
    @domain.items.select('timeout', 'next_time', 'cron', 'delay', 'data', 'timezone',
                        :where => "timeout > '#{int_encode(0)}'",  # required by SimpleDB
                        :order => [:timeout, :asc],
                        :consistent_read => @consistent_read,
                        :limit => MAX_SELECT_ROW) {|itemdata|
      id = itemdata.name
      attrs = itemdata.attributes

      next_time = int_decode(attrs['next_time'].first)
      cron = attrs['cron'].first
      delay = int_decode(attrs['delay'].first)
      data = attrs['data'].first
      timezone = attrs['timezone'].first
      timeout = int_decode(attrs['timeout'].first)

      yield id, cron, delay, data, next_time, timeout, timezone
    }
  end

  MAX_SELECT_ROW = 4

  def acquire(timeout, now=Time.now.to_i)
    while true
      rows = 0
        @domain.items.select('timeout', 'next_time', 'cron', 'delay', 'data', 'timezone',
                          :where => "timeout <= '#{int_encode(now)}'",
                          :order => [:timeout, :asc],
                          :consistent_read => @consistent_read,
                          :limit => MAX_SELECT_ROW) {|itemdata|
        begin
          id = itemdata.name
          attrs = itemdata.attributes

          @domain.items[id].attributes.replace('timeout'=>int_encode(timeout),
              :if=>{'timeout'=>attrs['timeout'].first})

          next_time = int_decode(attrs['next_time'].first)
          cron = attrs['cron'].first
          delay = int_decode(attrs['delay'].first)
          data = attrs['data'].first
          timezone = attrs['timezone'].first
          salt = int_encode(timeout)

          return [id,salt], Task.new(id, next_time, cron, delay, data, timezone)

        rescue AWS::SimpleDB::Errors::ConditionalCheckFailed, AWS::SimpleDB::Errors::AttributeDoesNotExist
        end

        rows += 1
      }
      if rows < MAX_SELECT_ROW
        return nil
      end
    end
  end

  def finish(token, next_time, timeout)
    begin
      id, salt = *token
      @domain.items[id].attributes.replace('timeout'=>int_encode(timeout), 'next_time'=>int_encode(next_time),
          :if=>{'timeout'=>salt})
      return true
    rescue AWS::SimpleDB::Errors::ConditionalCheckFailed, AWS::SimpleDB::Errors::AttributeDoesNotExist
      return false
    end
  end

  def add_checked(id, cron, delay, data, next_time, timeout, timezone)
    begin
      hash = {}
      hash['timeout'] = int_encode(timeout)
      hash['next_time'] = int_encode(next_time)
      hash['cron'] = cron
      hash['delay'] = int_encode(delay)
      hash['data'] = data
      hash['timezone'] = timezone if timezone
      hash[:unless] = 'timeout'
      @domain.items[id].attributes.replace()
      return true
    rescue AWS::SimpleDB::Errors::ConditionalCheckFailed, AWS::SimpleDB::Errors::ExistsAndExpectedValue
      return nil
    end
  end

  def delete(id)
    # TODO return value
    begin
      @domain.items[id].delete
      return true
    rescue AWS::SimpleDB::Errors::ConditionalCheckFailed, AWS::SimpleDB::Errors::AttributeDoesNotExist
      return false
    end
  end

  def get(id)
    attrs = @domain.items[id].data.attributes
    cron = attrs['cron'].first
    unless cron
      return nil
    end
    delay = int_decode(attrs['delay'].first)
    data = attrs['data'].first
    timezone = attrs['timezone'].first
    next_time = int_decode(attrs['next_time'].first)
    return cron, delay, data, timezone, next_time
  end

  def modify_checked(id, cron, delay, data, timezone)
    unless get(id)
      return false
    end
    @domain.items[id].attributes.replace('cron'=>cron, 'delay'=>int_encode(delay), 'data'=>data, 'timezone'=>timezone)
    return true
  end

  def modify_sched_checked(id, cron, delay)
    unless get(id)
      return false
    end
    @domain.items[id].attributes.replace('cron'=>cron, 'delay'=>int_encode(delay))
    return true
  end

  def modify_data_checked(id, data)
    unless get(id)
      return false
    end
    @domain.items[id].attributes.replace('data'=>data)
    return true
  end

  private
  def int_encode(num)
    "%08x" % num
  end

  def int_decode(str)
    str.to_i(16)
  end
end


end

