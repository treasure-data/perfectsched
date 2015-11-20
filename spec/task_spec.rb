require 'spec_helper'

describe PerfectSched::Task do
  let (:client){ double('client') }
  let (:key){ double('key') }
  let (:attributes){ double('attributes') }
  let (:scheduled_time){ double('scheduled_time') }
  let (:task_token){ double('task_token') }
  let (:task){ Task.new(client, key, attributes, scheduled_time, task_token) }

  describe '.new' do
    it 'returns a Task' do
      expect(task).to be_an_instance_of(Task)
      expect(task.instance_variable_get(:@scheduled_time)).to eq(scheduled_time)
      expect(task.instance_variable_get(:@task_token)).to eq(task_token)
    end
  end

  describe '#scheduled_time' do
    it 'returns the scheduled_time' do
      expect(task.scheduled_time).to eq(scheduled_time)
    end
  end

  describe '#release!' do
    it 'calls client.release' do
      options = double('options')
      ret = double('ret')
      expect(client).to receive(:release).with(task_token, options).and_return(ret)
      expect(task.release!(options)).to eq(ret)
    end
  end

  describe '#retry!' do
    it 'calls client.retry' do
      options = double('options')
      ret = double('ret')
      expect(client).to receive(:retry).with(task_token, options).and_return(ret)
      expect(task.retry!(options)).to eq(ret)
    end
  end

  describe '#finish!' do
    it 'calls client.finish' do
      options = double('options')
      ret = double('ret')
      expect(client).to receive(:finish).with(task_token, options).and_return(ret)
      expect(task.finish!(options)).to eq(ret)
    end
  end
end
