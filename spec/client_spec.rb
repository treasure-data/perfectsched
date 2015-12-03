require 'spec_helper'

describe Client do
  let (:config){ {} }
  let (:client){ Client.new(config) }
  let (:ret){ double('ret') }
  let (:backend){ double('backend') }
  let (:options){ double('options') }
  let (:task_token){ double('task_token') }
  let (:key){ double('key') }
  before do
    allow(Backend).to receive(:new_backend) \
      .with(kind_of(Client), config).and_return(backend)
  end
  describe '.new' do
    subject { client }
    it {
      is_expected.to be_an_instance_of(Client) }
  end
  describe '#backend' do
    subject { client.backend }
    it { is_expected.to eq backend }
  end
  describe '#config' do
    subject { client.config }
    it { is_expected.to eq config }
  end
  describe '#init_database' do
    subject { client.init_database(options) }
    before { expect(backend).to receive(:init_database).with(options).and_return(ret) }
    it { is_expected.to eq ret }
  end
  describe '#get_schedule_metadata' do
    subject { client.get_schedule_metadata(key, options) }
    before { expect(backend).to receive(:get_schedule_metadata).with(key, options).and_return(ret) }
    it { is_expected.to eq ret }
  end
  describe '#delete' do
    subject { client.delete(key, options) }
    before { expect(backend).to receive(:delete).with(key, options).and_return(ret) }
    it { is_expected.to eq ret }
  end
  describe '#modify' do
    subject { client.modify(key, options) }
    before { expect(backend).to receive(:modify).with(key, options).and_return(ret) }
    it { is_expected.to eq ret }
  end
  describe '#list' do
    let (:pr){ proc{} }
    subject { client.list(key, &pr) }
    before { expect(backend).to receive(:list).with(key){|*_, &b| expect(b).to eq pr; ret} }
    it { is_expected.to eq ret }
  end
  describe '#acquire' do
    let (:alive_time){ double('alive_time') }
    let (:max_acquire){ double('max_acquire') }
    subject { client.acquire(options) }
    before { expect(backend).to receive(:acquire).with(alive_time, max_acquire, options).and_return(ret) }
    context 'options are given' do
      let (:options){ {alive_time: alive_time, max_acquire: max_acquire} }
      it { is_expected.to eq ret }
    end
    context 'alive_time options is not given' do
      let (:max_acquire){ 1 }
      let (:options){ {} }
      let (:config){ {alive_time: alive_time} }
      it { is_expected.to eq ret }
    end
  end
  describe '#release' do
    let (:alive_time){ double('alive_time') }
    subject { client.release(task_token, options) }
    before { expect(backend).to receive(:release).with(task_token, alive_time, options).and_return(ret) }
    context 'alive_time options is given' do
      let (:options){ {alive_time: alive_time} }
      it { is_expected.to eq ret }
    end
    context 'alive_time options is not given' do
      let (:options){ {} }
      let (:config){ {alive_time: alive_time} }
      it { is_expected.to eq ret }
    end
  end
  describe '#heartbeat' do
    let (:alive_time){ double('alive_time') }
    subject { client.heartbeat(task_token, options) }
    before { expect(backend).to receive(:heartbeat).with(task_token, alive_time, options).and_return(ret) }
    context 'alive_time options is given' do
      let (:options){ {alive_time: alive_time} }
      it { is_expected.to eq ret }
    end
    context 'alive_time options is not given' do
      let (:options){ {} }
      let (:config){ {alive_time: alive_time} }
      it { is_expected.to eq ret }
    end
  end
  describe '#retry' do
    let (:retry_wait){ double('retry_wait') }
    subject { client.retry(task_token, options) }
    before { expect(backend).to receive(:heartbeat).with(task_token, retry_wait, options).and_return(ret) }
    context 'retry_wait options is given' do
      let (:options){ {retry_wait: retry_wait} }
      it { is_expected.to eq ret }
    end
    context 'retry_wait options is not given' do
      let (:options){ {} }
      let (:config){ {retry_wait: retry_wait} }
      it { is_expected.to eq ret }
    end
  end
  describe '#finish' do
    subject { client.finish(task_token, options) }
    before { expect(backend).to receive(:finish).with(task_token, options).and_return(ret) }
    it { is_expected.to eq ret }
  end
  describe '#close' do
    subject { client.close }
    before { expect(backend).to receive(:close).with(no_args).and_return(ret) }
    it { is_expected.to eq ret }
  end
end
