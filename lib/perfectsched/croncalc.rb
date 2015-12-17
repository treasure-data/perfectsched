require 'chrono'
require 'tzinfo'

module PerfectSched
  class CronCalc
    def cron_time(cron, timestamp, timezone)
      next_time(cron, timestamp-1, timezone)
    end

    def next_time(cron, before_timestamp, timezone)
      t = Time.find_zone!(timezone || 'UTC'.freeze).at(before_timestamp)
      Chrono::NextTime.new(now: t, source: cron).to_time.to_i
    end
  end
end
