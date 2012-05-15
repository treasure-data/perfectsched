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

  class Daemon
    def self.run(runner, &block)
      new(runner).run
    end

    def initialize(runner, &block)
      @runner = runner
      @config_load_proc = block
      @finished = false
    end

    def run
      config = load_config
      @worker = Worker.new(config)
      begin
        @sig = install_signal_handlers
        begin
          until @finished
            @worker.run
          end
        ensure
          @sig.shutdown
        end
      ensure
        @worker.close
      end
      nil
    end

    def stop
      @log.info "stop"
      @finished = true
      @worker.stop
      return true
    end

    def restart
      @log.info "reload"
      begin
        config = load_config
        worker = Worker.new(config)
      rescue
        # TODO log
        return false
      end
      current = @worker
      @worker = worker
      current.shutdown
      return true
    end

    def log_reopen
      @log.info "reopen a log file"
      @log.reopen!
      return true
    end

    private
    def load_config
      raw_config = @config_load_proc.call
      config = {}
      raw_config.each_pair {|k,v| config[k.to_sym] = v }

      log = DaemonsLogger.new(config[:log] || STDERR)
      if old_log = @log
        old_log.close
      end
      @log = log

      config[:logger] = log

      return config
    end

    def install_signal_handlers(&block)
      SignalThread.new do |sig|
        sig.trap :TERM do
          stop
        end
        sig.trap :INT do
          stop
        end

        sig.trap :QUIT do
          stop
        end

        sig.trap :USR1 do
          restart
        end

        #sig.trap :USR2 do
        #  restart
        #end

        sig.trap :HUP do
          log_reopen
        end

        sig.trap :WINCH do
          restart
        end

        sig.trap :CONT do
          log_reopen
        end

        trap :CHLD, "SIG_IGN"
      end
    end
  end

end

