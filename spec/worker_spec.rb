require 'spec_helper'

describe Worker do
  let (:logger){ double('logger').as_null_object }
  let (:runner){ double('runner') }
  let (:config){ {} }
  let (:worker){ Worker.new(runner, config) }
  before do
    allow(DaemonsLogger).to receive(:new).and_return(logger)
  end

  describe '.run' do
    it 'calls Worker.new.run without block' do
      expect(worker).to receive(:run).with(no_args)
      expect(Worker).to receive(:new).with(runner, config) do |*args, &block|
        expect(block).to be_nil
        worker
      end
      Worker.run(runner, config)
    end
    it 'calls Worker.new.run with block' do
      expect(worker).to receive(:run).with(no_args)
      expect(Worker).to receive(:new).with(runner, nil) do |*args, &block|
        expect(block).to be_a(Proc)
        worker
      end
      Worker.run(runner){ }
    end
  end

  describe '.new' do
    it 'creates a Worker without block' do
      expect(worker).to be_an_instance_of(Worker)
      expect(worker.instance_variable_get(:@runner)).to eq(runner)
      expect(worker.instance_variable_get(:@config_load_proc)).to be_an_instance_of(Proc)
      expect(worker.instance_variable_get(:@finished)).to be false
    end
    it 'creates a Worker with block' do
      worker = Worker.new(runner){ }
      expect(worker).to be_an_instance_of(Worker)
      expect(worker.instance_variable_get(:@runner)).to eq(runner)
      expect(worker.instance_variable_get(:@config_load_proc)).to be_an_instance_of(Proc)
      expect(worker.instance_variable_get(:@finished)).to be false
    end
  end

  describe '#run' do
    let (:sig) do
      sig = double('sig')
      expect(sig).to receive(:stop)
      sig
    end
    let (:engine) do
      engine = double('engine')
      expect(engine).to receive(:run){ worker.instance_variable_set(:@finished, true) }
      expect(engine).to receive(:shutdown)
      engine
    end
    it 'creates a Worker without block' do
      expect(worker).to receive(:install_signal_handlers).and_return(sig)
      expect(Engine).to receive(:new).with(runner, kind_of(Hash)).and_return(engine)
      expect(worker.instance_variable_get(:@runner)).to eq(runner)
      expect(worker.instance_variable_get(:@config_load_proc)).to be_an_instance_of(Proc)
      expect(worker.instance_variable_get(:@finished)).to be false
      expect(worker.run).to be_nil
    end
    it 'rescues error' do
      allow(worker).to receive(:install_signal_handlers).and_raise(RuntimeError)
      expect(worker.run).to be_nil
    end
  end

  describe '#stop' do
    context 'engine is not set' do
      it 'returns true' do
        expect(worker.stop).to be true
        expect(worker.instance_variable_get(:@finished)).to be true
      end
    end
    context 'engine is set' do
      let (:engine){ double('engine') }
      before do
        worker.instance_variable_set(:@engine, engine)
      end
      context 'succeed to stop engine' do
        before do
          expect(engine).to receive(:stop)
        end
        it 'returns true' do
          expect(worker.stop).to be true
          expect(worker.instance_variable_get(:@finished)).to be true
        end
      end
      context 'fail to stop engine' do
        before do
          expect(engine).to receive(:stop).and_raise(RuntimeError)
        end
        it 'returns false' do
          expect(worker.stop).to be false
          expect(worker.instance_variable_get(:@finished)).to be true
        end
      end
    end
  end

  describe '#restart' do
    let (:engine){ double('engine') }
    let (:old_engine){ double('old_engine') }
    before do
      worker.instance_variable_set(:@engine, old_engine)
      expect(Engine).to receive(:new).with(runner, kind_of(Hash)).and_return(engine)
    end
    context 'succeed to shutdown old engine' do
      before do
        expect(old_engine).to receive(:shutdown)
      end
      it 'returns true' do
        expect(worker.restart).to be true
      end
    end
    context 'fail to shutdown old engine' do
      before do
        expect(old_engine).to receive(:shutdown).and_raise(RuntimeError)
      end
      it 'returns false' do
        expect(worker.restart).to be false
      end
    end
  end

  describe '#replace' do
    context 'called at the first time' do
      let (:pid){ double('pid') }
      it 'returns self' do
        expect(Process).to receive(:spawn).with(*([$0]+ARGV)).and_return(pid)
        expect(worker).to receive(:stop)
        expect(worker.replace).to eq(worker)
      end
      it 'returns self' do
        command = double('command')
        expect(Process).to receive(:spawn).with(command).and_return(pid)
        expect(worker).to receive(:stop)
        expect(worker.replace(command)).to eq(worker)
      end
    end
    context 'already called' do
      it 'returns true' do
        expect(worker).to receive(:stop).and_raise(RuntimeError)
        expect(worker.replace(double)).to be false
      end
    end
  end

  describe '#logrotated' do
    it 'returns true' do
      expect(logger).to receive(:reopen!)
      expect(worker.logrotated).to be true
    end
    it 'rescues error and returns false' do
      expect(logger).to receive(:reopen!).and_raise(RuntimeError)
      expect(worker.logrotated).to be false
    end
  end

  describe 'install_signal_handlers' do
    let (:engine){ double('engine', shutdown: nil) }
    before do
      expect(Engine).to receive(:new).with(runner, kind_of(Hash)).and_return(engine)
    end
    it 'traps TERM and stop the worker' do
      allow(engine).to receive(:run){ Process.kill(:TERM, $$) }
      expect(worker).to receive(:stop).and_call_original
      worker.run
    end
    it 'traps INT and stop the worker' do
      allow(engine).to receive(:run){ Process.kill(:INT, $$) }
      expect(worker).to receive(:stop).and_call_original
      worker.run
    end
    it 'traps QUIT and stop the worker' do
      allow(engine).to receive(:run){ Process.kill(:QUIT, $$) }
      expect(worker).to receive(:stop).and_call_original
      worker.run
    end
    it 'traps USR1 and restart the worker' do
      allow(engine).to receive(:run){ Process.kill(:USR1, $$) }
      expect(worker).to receive(:restart){ worker.stop }
      worker.run
    end
    it 'traps HUP and restart the worker' do
      allow(engine).to receive(:run){ Process.kill(:HUP, $$) }
      expect(worker).to receive(:restart){ worker.stop }
      worker.run
    end
    it 'traps USR2 and logrotated' do
      allow(engine).to receive(:run){ Process.kill(:USR2, $$) }
      expect(worker).to receive(:logrotated){ worker.stop }
      worker.run
    end
  end
end
