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
  module Application

    class Dispatch < Runner
      # Runner interface
      def initialize(task)
        base = self.class.router.route(task.key)
        unless base
          task.retry!  # TODO or release?
          raise "Unknown task key #{task.key.inspect}"   # TODO error class
        end
        @runner = base.new(task)
        super
      end

      attr_reader :runner

      def run
        @runner.run
      end

      # DSL interface
      extend RouterDSL
    end

  end
end

