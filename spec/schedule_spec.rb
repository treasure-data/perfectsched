require 'spec_helper'

describe Schedule do
  let (:schedule){ Schedule.new(client, key) }
  let (:client){ double('client') }
  let (:key){ double('key') }
  let (:ret){  double('ret') }
  let (:options){ double('options') }
  describe '.new' do
    subject { schedule }
    it { is_expected.to be_an_instance_of(Schedule) }
  end
  describe '#key' do
    subject { schedule.key }
    it { is_expected.to eq key }
  end
  describe '#delete!' do
    subject { schedule.delete!(options) }
    it do
      expect(client).to receive(:delete).with(key, options).and_return(ret)
      is_expected.to eq ret
    end
  end
  describe '#metadata' do
    subject { schedule.metadata(options) }
    it do
      expect(client).to receive(:get_schedule_metadata).with(key, options).and_return(ret)
      is_expected.to eq ret
    end
  end
  describe '#exists?' do
    subject { schedule.exists?(options) }
    context 'metadata() works' do
      it do
        expect(schedule).to receive(:metadata).with(options)
        is_expected.to eq true
      end
    end
    context 'metadata() raises NotFoundError' do
      it do
        expect(schedule).to receive(:metadata).with(options).and_raise(NotFoundError)
        is_expected.to be false
      end
    end
  end
  describe '#inspect' do
    subject { schedule.inspect }
    it { is_expected.to eq "#<PerfectSched::Schedule @key=#{key.inspect}>" }
  end
end

describe ScheduleWithMetadata do
  let (:sm){ ScheduleWithMetadata.new(client, key, attributes) }
  let (:client){ double('client') }
  let (:key){ double('key') }
  let (:ret){  double('ret') }
  let (:attributes){ double('attributes') }
  describe '.new' do
    subject { sm }
    it { is_expected.to be_an_instance_of(ScheduleWithMetadata) }
  end
  describe '#inspect' do
    subject { sm.inspect }
    it { is_expected.to eq "#<PerfectSched::ScheduleWithMetadata @key=#{key.inspect} @attributes=#{attributes.inspect}>" }
  end
end
