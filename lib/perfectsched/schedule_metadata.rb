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

  module ScheduleMetadataAccessors
    attr_reader :attributes

    def data
      @attributes[:data]
    end

    def cron
      @attributes[:cron]
    end

    def delay
      @attributes[:delay]
    end

    def timezone
      @attributes[:timezone]
    end

    def next_time
      @attributes[:next_time]
    end

    def next_run_time
      @attributes[:next_run_time]
    end

    alias scheduled_time next_time

    alias scheduled_run_time next_run_time
  end

  class ScheduleMetadata
    include Model

    def initialize(client, key, attributes)
      super(client)
      @key = key
    end

    def schedule
      Schedule.new(@client, @key)
    end

    def inspect
      "#<#{self.class} @key=#{@key.inspect} @attributes=#{@attributes.inspect}>"
    end

    include ScheduleMetadataAccessors
  end

end
