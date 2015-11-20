require 'spec_helper'

describe PerfectSched::Application::UndefinedDecisionError do
  it { is_expected.to be_an_instance_of(PerfectSched::Application::UndefinedDecisionError) }
  it { is_expected.to be_a(Exception) }
end

describe PerfectSched::Application::Decider do
  let (:task){ double('task') }
  let (:schedules){ double('schedules') }
  let (:base){ double('base', schedules: schedules, task: task) }
  let (:decider) { PerfectSched::Application::Decider.new(base) }
  describe '#new' do
    it 'returns a decider' do
      expect(decider).to be_an_instance_of(PerfectSched::Application::Decider)
      expect(decider.instance_variable_get(:@base)).to eq(base)
    end
  end

  describe '#schedules' do
    it 'returns @base.schedules' do
      expect(decider.schedules).to eq(schedules)
    end
  end

  describe '#task' do
    let (:decider) do
      base = double('base')
      allow(base).to receive(:task).exactly(:once).and_return(task)
      PerfectSched::Application::Decider.new(base)
    end
    it 'calls @base.task' do
      expect(decider.task).to eq(task)
    end
  end

  describe '#decide!' do
    it 'calls the specified method' do
      opts = double('opts')
      ret = double('ret')
      allow(decider).to receive(:foo).exactly(:once).with(opts).and_return(ret)
      expect(decider.decide!(:foo, opts)).to eq(ret)
    end
    it 'raises UndefinedDecisionError on unknown method' do
      expect{ decider.decide!(:foo, double) }.to raise_error(PerfectSched::Application::UndefinedDecisionError)
    end
  end
end

describe PerfectSched::Application::DefaultDecider do
  subject { PerfectSched::Application::DefaultDecider.new(nil) }
  it { is_expected.to be_a(PerfectSched::Application::Decider) }
  it { is_expected.to be_an_instance_of(PerfectSched::Application::DefaultDecider) }
end
