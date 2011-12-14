
module PerfectSched


class Engine
  def initialize(backend, queue, log, conf)
    require 'time'
    @backend = backend
    @queue = queue
    @log = log

    @timeout = conf[:timeout]
    @poll_interval = conf[:poll_interval] || 1

    @croncalc = CronCalc.new
    @finished = false
  end

  def finished?
    @finished
  end

  def run
    until finished?
      @log.debug "polling... #{@timeout} #{@poll_interval}"
      token, task = @backend.acquire(Time.now.to_i+@timeout)

      unless token
        sleep @poll_interval
        next
      end

      process(token, task)
    end
  end

  def process(token, task)
    @log.info "processing schedule id=#{task.id} time=#{Time.at(task.time).iso8601} at #{Time.now.iso8601}"

    begin
      id = gen_id(task)
      @queue.submit(id, task.data)
      # ignore already exists error

      next_time = @croncalc.next_time(task.cron, task.time, task.timezone)
      next_run = next_time + task.delay
      @backend.finish(token, next_time, next_run)

      @log.info "submitted schedule id=#{task.id}"

    rescue
      @log.info "failed schedule id=#{task.id}: #{$!}"
    end
  end

  def stop
    @finished = true
  end

  def shutdown
  end

  private
  def gen_id(task)
    "#{task.id}.#{task.time}"
  end
end


end

