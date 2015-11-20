require 'spec_helper'

describe Runner do
  let (:client){ double('client') }
  let (:task){ double('task', client: client) }
  let (:runner){ Runner.new(task) }
  describe '.new' do
    subject { runner }
    it { is_expected.to be_an_instance_of(Runner) }
  end
  describe '#task' do
    subject { runner.task }
    it { is_expected.to eq task }
  end
  describe '#schedules' do
    subject { runner.schedules }
    it do
      schedule_collection = double('schedule_collection')
      expect(ScheduleCollection).to receive(:new).with(client).and_return(schedule_collection)
      is_expected.to eq schedule_collection
    end
  end
end
