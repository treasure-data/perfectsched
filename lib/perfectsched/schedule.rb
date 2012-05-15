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

  class Schedule
    include Model

    def initialize(client, key)
      super(client)
      @key = key
    end

    attr_reader :key

    def delete!(options={})
      @client.delete(@key, options)
    end

    def metadata(options={})
      @client.get_schedule_metadata(@key, options)
    end

    def exists?(options={})
      metadata(options)
      true
    rescue NotFoundError
      false
    end

    def inspect
      "#<#{self.class} @key=#{@key.inspect}>"
    end
  end

  class ScheduleWithMetadata < Schedule
    def initialize(client, key, attributes)
      super(client, key)
      @attributes = attributes
    end

    def inspect
      "#<#{self.class} @key=#{@key.inspect} @attributes=#{@attributes.inspect}>"
    end

    include ScheduleMetadataAccessors
  end

end

