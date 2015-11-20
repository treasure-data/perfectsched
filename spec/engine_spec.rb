require 'spec_helper'

describe PerfectSched::Engine do
  let (:logger){ double('logger').as_null_object }
  let (:runner){ double('runner') }
  let (:scheds){ double('scheds') }
  let (:config){ {logger: logger} }
  let (:engine) do
    Engine.new(runner, config)
  end
  before do
    expect(PerfectSched).to receive(:open).with(config).and_return(scheds)
  end

  describe '.new' do
    it 'returns an Engine' do
      engine = Engine.new(runner, config)
      expect(engine).to be_an_instance_of(Engine)
      expect(engine.instance_variable_get(:@runner)).to eq(runner)
      expect(engine.instance_variable_get(:@poll_interval)).to eq(1.0)
      expect(engine.instance_variable_get(:@log)).to eq(logger)
      expect(engine.instance_variable_get(:@running_flag)).to be_a(BlockingFlag)
      expect(engine.instance_variable_get(:@finish_flag)).to be_a(BlockingFlag)
      expect(engine.instance_variable_get(:@scheds)).to be_a(PerfectSched)
    end
  end

  describe '#run' do
    it 'runs until stopped' do
      rflag = engine.instance_variable_get(:@running_flag)
      fflag = engine.instance_variable_get(:@finish_flag)
      task1 = double('task1')
      task2 = double('task2')
      allow(scheds).to receive(:poll).and_return(task1, nil, task2)
      expect(runner).to receive(:new).exactly(:twice) do |task|
        expect(rflag.set?).to be true
        r = double('r')
        case task
        when task1
          expect(r).to receive(:run)
        when task2
          expect(r).to receive(:run){ fflag.set! }
        else
          raise ArgumentError
        end
        r
      end
      expect(engine.run).to eq(engine)
      expect(rflag.set?).to be false
    end
  end

  describe '#stop' do
    it 'sets finish_flag' do
      expect(engine.stop).to eq(engine)
      expect(engine.instance_variable_get(:@finish_flag).set?).to eq true
    end
  end

  describe '#join' do
    it 'waits running flag is set' do
      expect(engine.join).to eq(engine)
      expect(engine.instance_variable_get(:@running_flag).set?).to eq false
    end
  end

  describe '#close' do
    it 'closes scheds' do
      expect(scheds).to receive(:close)
      expect(engine.close).to eq(engine)
    end
  end

  describe '#shutdown' do
    it 'calls stop, join, and close' do
      expect(engine).to receive(:stop)
      expect(engine).to receive(:join)
      expect(engine).to receive(:close).and_return(engine)
      expect(engine.shutdown).to eq(engine)
    end
  end
end
