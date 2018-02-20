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
    # SignalQueue is obsolete because it does not run with ruby >= 2.0.0.
    # See ddbf04c9 and use SignalThread instead.
    :SignalQueue => 'perfectsched/signal_queue',
    :SignalThread => 'perfectsched/signal_thread',
    :Task => 'perfectsched/task',
    :TaskMonitor => 'perfectsched/task_monitor',
    :Worker => 'perfectsched/worker',
    :VERSION => 'perfectsched/version',
  }.each_pair {|k,v|
    autoload k, File.expand_path(v, File.dirname(__FILE__))
  }
  [
    'perfectsched/version',
    'perfectsched/error',
  ].each {|v|
    require File.expand_path(v, File.dirname(__FILE__))
  }

  require 'chrono'
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
    ts = timestamp - 1 # compatibility
    t = Time.find_zone!(timezone || 'UTC'.freeze).at(ts)
    Chrono::NextTime.new(now: t, source: cron).to_time.to_i
  end

  def self.next_time(cron, before_timestamp, timezone)
    cron_time(cron, before_timestamp+1, timezone)
  end
end

