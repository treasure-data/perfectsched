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

  class Worker
    def initialize(config, runner)
      @config = config
      @runner = runner

      @poll_interval = @config[:poll_interval] || 1.0
      @log = @config[:logger] || Logger.new(STDERR)

      @running_flag = BlockingFlag.new
      @finish_flag = BlockingFlag.new

      @scheds = PerfectSched.open(@config)
    end

    def run
      @running_flag.set_region do
        until @finish_flag.set?
          task = scheds.poll
          if task
            @runner.run(task)
          else
            @finish_flag.wait(@config[:poll_interval)
          end
        end
      end
      self
    end

    def stop
      @finish_flag.set!
      self
    end

    def join
      @running_flag.wait while @running_flag.set?
      self
    end

    def close
      @scheds.close
      self
    end

    def shutdown
      stop
      join
      close
    end
  end

end
