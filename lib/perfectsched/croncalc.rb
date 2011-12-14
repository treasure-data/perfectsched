
module PerfectSched


class CronCalc
  def initialize
    require 'cron-spec'
    require 'tzinfo'
    # TODO optimize
  end

  def next_time(cron, time, timezone)
    tab = CronSpec::CronSpecification.new(cron)
    tz = TZInfo::Timezone.get(timezone) if timezone
    while true
      time += 60
      t = Time.at(time)
      t = tz.utc_to_local(t.utc) if tz
      if tab.is_specification_in_effect?(t)
        return time
      end
      # FIXME break
    end
  end
end


end

