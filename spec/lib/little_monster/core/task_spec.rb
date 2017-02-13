require 'spec_helper'

describe LittleMonster::Core::Task do
  let(:options) do
    {
      id: 0,
      data: { a: 'b' }
    }
  end

  let(:job) { MockJob.new options }

  let(:mock_task) { MockJob::Task.new({}) }

  after :each do
    load './spec/mock/mock_job.rb'
  end

  describe 'attr_readers' do
    it 'has data' do
      expect(mock_task).to respond_to(:data)
    end
  end

  describe '#initialize' do
    let(:data) { LittleMonster::Core::Job::Data.new job }
    let(:mock_task) { MockJob::Task.new(data) }

    it 'sets data' do
      expect(mock_task.data).to eq(data)
    end
  end

  describe '#set_default_values' do
    let(:params) do
      {
        data: LittleMonster::Core::Job::Data.new(job),
        job_id: 0,
        job_logger: double,
        cancelled_callback: double,
        retries: 0,
        max_retries: 2,
        retry_callback: double
      }
    end

    it 'sets data' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.data).to eq(params[:data])
    end

    it 'sets parent_logger' do
      mock_task.logger
      mock_task.send(:set_default_values, params)
      expect(mock_task.logger.parent_logger).to eq(params[:job_logger])
    end

    it 'sets cancelled_callback' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.instance_variable_get('@cancelled_callback')).to eq(params[:cancelled_callback])
    end

    it 'sets job_id' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.instance_variable_get('@job_id')).to eq(params[:job_id])
    end

    it 'sets job_retries' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.instance_variable_get('@job_retries')).to eq(params[:retries])
    end

    it 'sets job_max_retries' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.instance_variable_get('@job_max_retries')).to eq(params[:max_retries])
    end

    it 'sets retry_callback' do
      mock_task.send(:set_default_values, params)
      expect(mock_task.instance_variable_get('@retry_callback')).to eq(params[:retry_callback])
    end
  end

  describe '#run' do
    before :each  do
      allow_any_instance_of(LittleMonster::Task).to receive(:run).and_call_original
    end

    it 'raises NotImplementedError if not implemented' do
      expect { LittleMonster::Task.new(nil).run }.to raise_error(NotImplementedError)
    end

    it 'executes the code in run if implemented' do
      expect { MockJob::Task.new(nil).run }.not_to raise_error
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

  describe '#is_cancelled?' do
    it 'returns false if no callback associated' do
      mock_task.instance_variable_set('@cancelled_callback', nil)
      expect(mock_task.is_cancelled?).to eq(false)
    end

    it 'returns false if callback returns false' do
      mock_task.instance_variable_set('@cancelled_callback', proc { false })
      expect(mock_task.is_cancelled?).to eq(false)
    end

    it 'returns true if callback returns true' do
      mock_task.instance_variable_set('@cancelled_callback', proc { true })
      expect(mock_task.is_cancelled?).to eq(true)
    end
  end
end
