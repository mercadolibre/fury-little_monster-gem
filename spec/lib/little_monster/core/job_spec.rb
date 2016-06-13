require 'spec_helper'

describe LittleMonster::Core::Job do
  after :each do
    load './spec/mock/mock_job.rb'
  end

  let(:params) { { a: 'b' } }
  let(:job) { MockJob.new params }

  context 'class level instance variables' do
    let(:job_class) { MockJob.new(nil).class }

    describe '::task_list' do
      let(:tasks) { [:mock_task_b, :mock_task_a] }

      it 'sets the task class level instance variable' do
        job_class.task_list(*tasks)
        expect(job_class.tasks).to eq(tasks)
      end
    end
  end

  describe '#initialize' do
    it 'sets the params' do
      expect(job.instance_variable_get('@params')).to eq(params)
    end

    it 'freezes the params' do
      expect(job.instance_variable_get('@params').frozen?).to be true
    end

    it 'sets current_task to nil' do
      expect(job.current_task).to be_nil
    end

    it 'sets status to pending' do
      expect(job.status).to eq(:pending)
    end
  end

  describe '#run' do
    before :each do
      allow(MockJob::TaskA).to receive(:new).and_call_original
      allow(MockJob::TaskB).to receive(:new).and_call_original
    end

    it 'sets status as running' do
      allow(job).to receive(:status=).and_call_original
      job.run
      expect(job).to have_received(:status=).with(:running).once.ordered
    end

    it 'exits if cancelled' do
      allow(job).to receive(:is_cancelled?).and_return(true)
      job.run
      expect(job.status).to eq(:cancelled)
    end

    it 'raises CancelError if is_cancelled' do
      allow_any_instance_of(MockJob::TaskA).to receive(:perform).and_call_original
      allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
      allow_any_instance_of(MockJob::TaskA).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
      allow(job).to receive(:cancel)
      job.run
      expect(job).to have_received(:cancel).with(LittleMonster::CancelError).once
    end

    it 'sets status as finished' do
      allow(job).to receive(:status=).and_call_original
      job.run
      expect(job).to have_received(:status=).with(:finished).once
    end

    it 'build the task class based on class parent module and symbol' do
      MockJob.task_list :task_a
      run_job(MockJob)
      expect(MockJob::TaskA).to have_received(:new)
    end

    it 'calls the first task with empty outputs' do
      job.run
      expect(MockJob::TaskA).to have_received(:new).with(params, {})
    end

    it 'calls the later task with chained outputs' do
      allow_any_instance_of(MockJob::TaskA).to receive(:run)
      allow_any_instance_of(MockJob::TaskA).to receive(:perform).and_return(mock_task_a: 1)
      job.run
      expect(MockJob::TaskB).to have_received(:new).with(params, mock_task_a: 1)
    end

    it 'returns the hash containing all outputs' do
      expect(job.run).to eq(mock_task_a: 'task_a_finished', mock_task_b: 'task_b_finished')
    end

    it 'sets status as error if task_name does not exist' do
      MockJob.task_list :not_existing_task
      f = MockJob.new params
      f.run
      expect(f.status).to eq(:error)
    end

    context 'when a task fails' do
      before :each do
        allow(job).to receive(:error).and_call_original
        allow(job).to receive(:abort_job)
      end

      it 'calls job.error on TaskError' do
        allow_any_instance_of(MockJob::TaskA).to receive(:run).and_raise(LittleMonster::TaskError)
        job.run
        expect(job).to have_received(:error).with(LittleMonster::TaskError)
      end

      it 'calls job.error on StandardError' do
        allow_any_instance_of(MockJob::TaskB).to receive(:run).and_raise(StandardError)
        job.run
        expect(job).to have_received(:error).with(StandardError).once
      end

      it 'calls job.abort on FatalTaskError' do
        allow_any_instance_of(MockJob::TaskB).to receive(:run).and_raise(LittleMonster::FatalTaskError)
        job.run
        expect(job).to have_received(:abort_job).with(LittleMonster::FatalTaskError)
      end

      it 'calls Task.error on TaskError' do
        mock_task = MockJob::TaskA.new(nil, nil)
        allow(MockJob::TaskA).to receive(:new).and_return(mock_task)
        allow_any_instance_of(MockJob::TaskA).to receive(:run).and_raise(LittleMonster::TaskError)
        allow(mock_task).to receive(:error)
        job.run
        expect(mock_task).to have_received(:error).with(LittleMonster::TaskError)
      end
    end
  end

  describe '#abort_job' do
    before :each do
      allow(job).to receive(:abort_job).and_call_original
      job.send(:abort_job, LittleMonster::FatalTaskError.new)
    end

    it 'sets status as failed' do
      expect(job.status).to eq(:failed)
    end

    it 'calls on_abort' do
      expect(job).to have_received(:abort_job).with(LittleMonster::FatalTaskError)
    end
  end

  describe '#error' do
    before :each do
      allow(job).to receive(:error).and_call_original
      allow(job).to receive(:on_error).and_call_original
      allow(job).to receive(:do_retry)
    end

    it 'does not abort if it did not receive a FatalTaskError' do
      allow(job).to receive(:abort_job)
      job.send(:error, LittleMonster::TaskError.new)
      expect(job).not_to have_received(:abort_job).with LittleMonster::FatalTaskError
    end

    it 'aborts if received a FatalTaskError' do
      allow(job).to receive(:abort_job)
      job.send(:error, LittleMonster::FatalTaskError.new)
      expect(job).to have_received(:abort_job).with LittleMonster::FatalTaskError
    end

    it 'calls do_retry if non FatalTaskError' do
      job.send(:error, LittleMonster::TaskError.new)
      expect(job).to have_received(:do_retry).with no_args
    end

    it 'calls on_error' do
      job.send(:error, LittleMonster::TaskError.new)
      expect(job).to have_received(:on_error).with(LittleMonster::TaskError)
    end

    it 'sets status to :error' do
      job.send(:error, LittleMonster::TaskError.new)
      expect(job.status).to be(:error)
    end
  end

  describe '#cancel' do
    before :each do
      allow(job).to receive(:cancel).and_call_original
      allow(job).to receive(:on_cancel).and_call_original
    end

    it 'sets status to :cancelled' do
      job.send(:cancel, LittleMonster::CancelError.new)
      expect(job.status).to be(:cancelled)
    end

    it 'calls on_cancel' do
      job.send(:cancel, LittleMonster::CancelError.new)
      expect(job).to have_received(:on_cancel).with(no_args)
    end
  end

  describe '#do_retry' do
    before :each do
      allow(job).to receive(:do_retry).and_call_original
    end

    after :each do
      MockJob.max_retries(-1)
    end

    it 'retries if max_retries = -1 (it is by default)' do
      ret_before = job.instance_variable_get '@retries'
      job.send('do_retry')
      expect(job.instance_variable_get('@retries')).to eq(ret_before + 1)
    end

    it 'retries if max_retries not reached' do
      MockJob.max_retries(5)
      job.instance_variable_set '@retries', 4
      job.send 'do_retry'
      expect(job.instance_variable_get('@retries')).to eq(5)
    end

    it 'does not retry if max retries reached' do
      allow(job).to receive(:abort_job)
      MockJob.max_retries(5)
      job.instance_variable_set '@retries', 5
      job.send 'do_retry'
      expect(job).to have_received(:abort_job).with(LittleMonster::MaxRetriesError)
    end
  end

  describe '#is_cancelled?' do
    it { job.send(:is_cancelled?) == false }
  end
end
