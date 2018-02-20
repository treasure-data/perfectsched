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
  class ScheduleError < StandardError
  end

  class AlreadyFinishedError < ScheduleError
  end

  class NotFoundError < ScheduleError
  end

  class AlreadyExistsError < ScheduleError
  end

  class PreemptedError < ScheduleError
  end

  class NotSupportedError < ScheduleError
  end

  class ConfigError < RuntimeError
  end

  class ProcessStopError < RuntimeError
  end

  # Applications can ignore these errors to achieve idempotency
  module IdempotentError
  end

  class IdempotentAlreadyFinishedError < AlreadyFinishedError
    include IdempotentError
  end

  class IdempotentAlreadyExistsError < AlreadyExistsError
    include IdempotentError
  end

  class IdempotentNotFoundError < NotFoundError
    include IdempotentError
  end

  class ProcessStopError < RuntimeError
  end

  class ImmediateProcessStopError < ProcessStopError
  end

  class GracefulProcessStopError < ProcessStopError
  end
end
