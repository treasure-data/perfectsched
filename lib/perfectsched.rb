#
# PerfectSched
#
# Copyright (C) 2012 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

module PerfectSched
  require 'json'
  require 'thread'  # Mutex, CoditionVariable

  {
    :Application => 'perfectsched/application',
    :Backend => 'perfectsched/backend',
    :BackendHelper => 'perfectsched/backend',
    :BlockingFlag => 'perfectsched/blocking_flag',
    :Client => 'perfectsched/client',
    :DaemonsLogger => 'perfectsched/daemons_logger',
    :Engine => 'perfectsched/engine',
    :Model => 'perfectsched/model',
    :Runner => 'perfectsched/runner',
    :ScheduleCollection => 'perfectsched/schedule_collection',
    :Schedule => 'perfectsched/schedule',
    :ScheduleWithMetadata => 'perfectsched/schedule',
    :ScheduleMetadata => 'perfectsched/schedule_metadata',
    :ScheduleMetadataAccessors => 'perfectsched/schedule_metadata',
    :SignalQueue => 'perfectsched/signal_queue',
    :Task => 'perfectsched/task',
    :Worker => 'perfectsched/worker',
  }.each_pair {|k,v|
    autoload k, File.expand_path(v, File.dirname(__FILE__))
  }
  [
    'perfectsched/version',
    'perfectsched/error',
  ].each {|v|
    require File.expand_path(v, File.dirname(__FILE__))
  }

  require 'cron-spec'
  require 'tzinfo'

  def self.open(config, &block)
    c = Client.new(config)
    begin
      q = ScheduleCollection.new(c)
      if block
        block.call(q)
      else
        c = nil
        return q
      end
    ensure
      c.close if c
    end
  end

  def self.cron_time(cron, timestamp, timezone)
    begin
      tab = CronSpec::CronSpecification.new(cron)
    rescue
      raise ArgumentError, "invalid cron format: #{$!}: #{cron.inspect}"
    end

    begin
      tz = TZInfo::Timezone.get(timezone) if timezone
    rescue
      raise ArgumentError, "unknown timezone: #{$!}: #{timezone.inspect}"
    end

    ts = (timestamp + 59) / 60 * 60
    while true
      t = Time.at(ts).utc
      t = tz.utc_to_local(t) if tz
      if tab.is_specification_in_effect?(t)
        return ts
      end
      ts += 60
      # FIXME break
    end
  end

  def self.next_time(cron, before_timestamp, timezone)
    cron_time(cron, before_timestamp+1, timezone)
  end
end

