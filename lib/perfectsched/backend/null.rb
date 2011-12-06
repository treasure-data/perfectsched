
module PerfectSched


class NullBackend < Backend
  def list(&block)
    nil
  end

  def acquire(timeout, now=Time.now.to_i)
    nil
  end

  def finish(token, next_time, timeout)
    true
  end

  def add_checked(id, cron, delay, data, next_time, timeout)
    true
  end

  def delete(id)
    true
  end

  def get(id)
    nil
  end

  def modify_checked(id, cron, delay, data)
    true
  end

  def modify_sched_checked(id, cron, delay)
    true
  end

  def modify_data_checked(id, data)
    true
  end
end


end

