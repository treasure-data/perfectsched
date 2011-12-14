
module PerfectSched


class Task
  def initialize(id, time, cron, delay, data, timezone=nil)
    @id = id
    @time = time
    @cron = cron
    @delay = delay
    @data = data
    @timezone = timezone
  end

  attr_reader :id, :time, :cron, :delay, :data, :timezone
end


class Backend
  def initialize
    @croncalc = CronCalc.new
  end

  # => list {|id,cron,delay,data,next_time,timeout| ... }
  def list(&block)
  end

  # => token, task
  def acquire(timeout, now=Time.now.to_i)
  end

  # => true (success) or false (canceled)
  def finish(token, next_time)
  end

  # => true (success) or nil (already exists)
  def add(id, cron, delay, data, start_time, timezone=nil)
    timezone = TZInfo::Timezone.get(timezone).name if timezone  # normalize
    first_time = @croncalc.next_time(cron, start_time.to_i, timezone)
    timeout = first_time + delay
    add_checked(id, cron, delay, data, first_time, timeout, timezone)
  end

  # => true (success) or nil (already exists)
  def add_checked(id, cron, delay, data, next_time, timeout, timezone)
  end

  # => true (success) or false (not found, canceled or finished)
  def delete(id)
  end

  # => true (success) or false (not found)
  def modify(id, cron, delay, data, timezone)
    cron = cron.strip
    @croncalc.next_time(cron, 0, timezone)
    modify_checked(id, cron, delay, data, timezone)
  end

  def modify_checked(id, cron, delay, data, timezone)
  end

  # => true (success) or false (not found)
  def modify_sched(id, cron, delay)
    cron_, delay_, data_, timezone = get(id)
    cron = cron.strip
    @croncalc.next_time(cron, 0, timezone)
    modify_sched_checked(id, cron, delay)
  end

  def modify_sched_checked(id, cron, delay)
  end

  # => true (success) or false (not found)
  def modify_data(id, data)
    modify_data_checked(id, data)
  end

  def modify_data_checked(id, data)
  end

  def close
  end
end


end

