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

    describe '::retries' do
      let(:retries) { 3 }

      it 'sets the max_retries class level instance variable' do
        job_class.retries(retries)
        expect(job_class.max_retries).to eq(retries)
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
    context 'on start' do
      it 'notifies status as running' do
        allow(job).to receive(:notify_status)
        job.run
        expect(job).to have_received(:notify_status).with(:running).once
      end
    end

    context 'on run' do
      before :each do
        allow(MockJob::TaskA).to receive(:new).and_call_original
        allow(MockJob::TaskB).to receive(:new).and_call_original
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

        context 'and job is not on retry limit' do
          it 'raises a job JobRetryError' do
            allow_any_instance_of(MockJob::TaskB).to receive(:run).and_raise(StandardError)
            expect{ job.run }.to raise_error(LittleMonster::JobRetryError)
          end
        end

        it 'calls job.error on an error' do
          allow_any_instance_of(MockJob::TaskB).to receive(:run).and_raise(StandardError)
          job.run rescue
          expect(job).to have_received(:error).with(StandardError).once
        end

        it 'calls job.abort on FatalTaskError' do
          allow_any_instance_of(MockJob::TaskB).to receive(:run).and_raise(LittleMonster::FatalTaskError)
          job.run rescue
          expect(job).to have_received(:abort_job).with(LittleMonster::FatalTaskError)
        end

        it 'calls Task.error on TaskError' do
          mock_task = MockJob::TaskA.new(nil, nil)
          allow(MockJob::TaskA).to receive(:new).and_return(mock_task)
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_raise(LittleMonster::TaskError)
          allow(mock_task).to receive(:error)
          job.run rescue
          expect(mock_task).to have_received(:error).with(LittleMonster::TaskError)
        end
      end
    end

    context 'when cancelled' do
      it 'sets status as cancelled' do
        allow(job).to receive(:is_cancelled?).and_return(true)
        job.run
        expect(job.status).to eq(:cancelled)
      end

      it 'notifies status as cancelled' do
        allow(job).to receive(:is_cancelled?).and_return(true)
        allow(job).to receive(:notify_status)
        job.run
        expect(job).to have_received(:notify_status).with(:cancelled).once
      end

      context 'and job is running a task' do
        it 'raises CancelError' do
          allow_any_instance_of(MockJob::TaskA).to receive(:perform).and_call_original
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
          allow_any_instance_of(MockJob::TaskA).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
          allow(job).to receive(:cancel)
          job.run
          expect(job).to have_received(:cancel).with(LittleMonster::CancelError).once
        end
      end
    end

    context 'on finish' do
      it 'notifies status as finished' do
        allow(job).to receive(:notify_status)
        job.run
        expect(job).to have_received(:notify_status).with(:finished).once
      end
    end
  end

  describe '#abort_job' do
    before :each do
      allow(job).to receive(:abort_job).and_call_original
      allow(job).to receive(:notify_status)
      job.send(:abort_job, LittleMonster::FatalTaskError.new)
    end

    it 'notifies status as error' do
      expect(job).to have_received(:notify_status).with(:error).once
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
    after :each do
      MockJob.retries(-1)
    end

    context 'if max retries is -1' do
      it 'raises JobRetryError'  do
        expect { job.send :do_retry }.to raise_error(LittleMonster::JobRetryError)
      end
    end

    context 'if max retries is not reached' do
      before :each do
        MockJob.retries 5
        job.instance_variable_set '@retries', 4
      end

      it 'increases retries by 1' do
        job.send :do_retry rescue
        expect(job.instance_variable_get('@retries')).to eq(5)
      end

      it 'raises JobRetryError'  do
        expect { job.send :do_retry }.to raise_error(LittleMonster::JobRetryError)
      end
    end


    context 'if max retries is reached' do
      before :each do
        allow(job).to receive(:abort_job)
        MockJob.retries 5
        job.instance_variable_set '@retries', 5
      end

      it 'does not retry' do
        job.send :do_retry
        expect(job).to have_received(:abort_job).with(LittleMonster::MaxRetriesError)
      end

      it 'does not retry' do
        expect { job.send :do_retry }.not_to raise_error(LittleMonster::JobRetryError)
      end
    end
  end

  describe '#is_cancelled?' do
    it { job.send(:is_cancelled?) == false }
  end
end
