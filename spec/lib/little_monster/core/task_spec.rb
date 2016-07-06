require 'spec_helper'

describe LittleMonster::Core::Task do
  let(:options) do
    {
      id: 0,
      params: { a: 'b' }
    }
  end

  let(:job) { MockJob.new options }

  let(:mock_task) { MockJob::Task.new({}, {}) }

  after :each do
    load './spec/mock/mock_job.rb'
  end

  describe 'attr_readers' do
    it 'has params' do
      expect(mock_task).to respond_to(:params)
    end

    it 'has data' do
      expect(mock_task).to respond_to(:data)
    end
  end

  describe '#initialize' do
    let(:params) { { a: 'b' } }
    let(:data) { LittleMonster::Core::Job::Data.new job }
    let(:mock_task) { MockJob::Task.new(params, data) }

    before :each do
      allow_any_instance_of(MockJob::Task).to receive(:set_default_values).and_call_original
    end

    it 'sets data' do
      expect(mock_task.instance_variable_get('@data')).to eq(data)
    end

    it 'sets params' do
      expect(mock_task.instance_variable_get('@params')).to eq(params)
    end

    context 'when it is not overriden' do
      it 'call set_default_values with params and datas' do
        mock_task
        expect(mock_task).to have_received(:set_default_values).with(params, data)
      end
    end
  end

  describe '#set_default_values' do
    let(:params) { { a: 'b' } }
    let(:data) { LittleMonster::Core::Job::Data.new job }
    let(:cancelled_callback) { double }
    let(:logger) { double }
    let(:mock_task) { MockJob::Task.new(params, data) }

    it 'sets params' do
      mock_task.send(:set_default_values, params, data)
      expect(mock_task.params).to eq(params)
    end

    it 'sets data' do
      mock_task.send(:set_default_values, params, data)
      expect(mock_task.data).to eq(data)
    end

    it 'sets logger if logger is not nil' do
      mock_task.logger
      mock_task.send(:set_default_values, params, data, logger)
      expect(mock_task.instance_variable_get('@logger')).to eq(logger)
    end

    it 'does not set logger if logger is nil' do
      mock_task.logger #call logger to get it initialized
      mock_task.send(:set_default_values, params, output, nil)
      expect(mock_task.instance_variable_get('@logger')).not_to be_nil
    end

    it 'sets cancelled_callback' do
      mock_task.send(:set_default_values, params, data, logger, cancelled_callback)
      expect(mock_task.instance_variable_get('@cancelled_callback')).to eq(cancelled_callback)
    end

    it 'sets cancelled_callback to nil if cancelled_callback is not sent' do
      mock_task.send(:set_default_values, params, data)
      expect(mock_task.instance_variable_get('@cancelled_callback')).to eq(nil)
    end
  end

  describe '#run' do
    before :each  do
      allow_any_instance_of(LittleMonster::Task).to receive(:run).and_call_original
    end

    it 'raises NotImplementedError if not implemented' do
      expect { LittleMonster::Task.new(nil, nil).run }.to raise_error(NotImplementedError)
    end

    it 'executes the code in run if implemented' do
      expect { MockJob::Task.new(nil, nil).run }.not_to raise_error
    end

    it 'raises CancelError if is_cancelled!' do
      allow(mock_task).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
      expect { mock_task.run }.to raise_error(LittleMonster::CancelError)
    end
  end

  describe '#error' do
    let(:on_error_callback) do
      on_error_callback = double
      allow(on_error_callback).to receive(:call)
      on_error_callback
    end

    before :each do
      allow(mock_task).to receive(:error).and_call_original
      allow(mock_task).to receive(:on_error).and_call_original
    end

    it 'calls on_error' do
      mock_task.error LittleMonster::TaskError.new
      expect(mock_task).to have_received(:on_error).with(LittleMonster::TaskError).once
    end
  end

  describe '#is_cancelled!' do
    it 'does nothing if there is no callback associated' do
      mock_task.instance_variable_set('@cancelled_callback', nil)
      expect { mock_task.is_cancelled! }.not_to raise_error
    end

    it 'does nothing if callback returns false' do
      mock_task.instance_variable_set('@cancelled_callback', proc { false })
      expect { mock_task.is_cancelled! }.not_to raise_error
    end

    it 'raises CancelError if callback returns true' do
      mock_task.instance_variable_set('@cancelled_callback', proc { true })
      expect { mock_task.is_cancelled! }.to raise_error(LittleMonster::CancelError)
    end
  end
end
