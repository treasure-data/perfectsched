
module PerfectSched


class CronCalc
  def initialize
    require 'cron-spec'
  end

  def next_time(cron, time)
    t = Time.at(time)
    tab = CronSpec::CronSpecification.new(cron)
    while true
      t += 60
      if tab.is_specification_in_effect?(t)
        return t.to_i
      end
      # FIXME break
    end
  end
end


end

