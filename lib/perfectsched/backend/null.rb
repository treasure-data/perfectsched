
module PerfectSched


class NullBackend < Backend
  def list(&block)
    nil
  end

  def acquire(timeout, now=Time.now.to_i)
    nil
  end

  def finish(token, next_time, timeout)
    false
  end

  def add_checked(id, cron, delay, data, next_time, timeout)
    nil
  end

  def delete(id)
    false
  end

  def get(id)
    nil
  end

  def modify_checked(id, cron, delay, data)
    false
  end

  def modify_sched_checked(id, cron, delay)
    false
  end

  def modify_data_checked(id, data)
    false
  end
end


end

