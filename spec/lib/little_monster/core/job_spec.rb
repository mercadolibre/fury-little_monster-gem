require 'spec_helper'

describe LittleMonster::Core::Job do
  after :each do
    load './spec/mock/mock_job.rb'
  end

  let(:options) do
    {
      id: 0,
      params: { a: 'b' }
    }
  end

  let(:job) { MockJob.new options }

  context 'class level instance variables' do
    let(:job_class) { MockJob.new.class }

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
    context 'given a full options hash' do
      let(:options) do
        {
          id: 1,
          params: { a: :b },
          tags: { tag: 'a tag' },
          retries: 2,
          current_task: :task_a,
          last_output: { b: :c }
        }
      end

      it { expect(job.id).to eq(options[:id]) }
      it { expect(job.params).to eq(options[:params]) }
      it { expect(job.tags).to eq(options[:tags]) }
      it { expect(job.retries).to eq(options[:retries]) }
      it { expect(job.current_task).to eq(options[:current_task]) }
      it { expect(job.output).to eq(options[:last_output]) }
    end

    context 'given empty options' do
      let(:options) { {} }

      it { expect(job.id).to be_nil }
      it { expect(job.params).to eq({}) }
      it { expect(job.tags).to eq({}) }
      it { expect(job.retries).to eq(0) }
      it { expect(job.current_task).to be_nil }
      it { expect(job.output).to be_instance_of(LittleMonster::Core::OutputData) }
    end

    it 'sets status to pending' do
      expect(job.status).to eq(:pending)
    end

    it 'freezes the params' do
      expect(job.params.frozen?).to be true
    end

    it 'freezes the tags' do
      expect(job.tags.frozen?).to be true
    end

    it 'notifies task list' do
      allow_any_instance_of(MockJob).to receive(:notify_task_list)
      expect(job).to have_received(:notify_task_list).once
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
        job.run
        expect(MockJob::TaskA).to have_received(:new)
      end

      context 'on mock job' do
        it 'calls the first task with empty outputs' do
          job.run
          expect(MockJob::TaskA).to have_received(:new).with(options[:params], LittleMonster::Core::OutputData)
        end

        it 'calls the later task with chained outputs' do
          task_a_output = double
          allow_any_instance_of(MockJob::TaskA).to receive(:run) { job.instance_variable_get('@output')[:task_a_output] = task_a_output }
          job.run
          expect(MockJob::TaskB).to have_received(:new).with(options[:params], LittleMonster::Core::OutputData)
          expect(job.instance_variable_get('@output')[:task_a_output]).to eq(task_a_output)
        end

        it 'notifies api task a finished with output' do
          output = LittleMonster::Core::OutputData.new(job)
          MockJob.tasks.each do |task|
            allow_any_instance_of(MockJob.task_class_for task).to receive(:run)
          end

          allow(job).to receive(:notify_current_task)
          job.run

          MockJob.tasks.each do |task|
            expect(job).to have_received(:notify_current_task).with(task, :finished)
          end
        end

        it 'returns the output of the entire output data' do
          job.run
          expect(job.instance_variable_get('@output')).to eq({ task_b: "task_b_finished" })
        end
      end


      it 'sets status as error if task_name does not exist' do
        MockJob.task_list :not_existing_task
        f = MockJob.new options
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

      context 'when api is down' do
        it 'raises APIUnreachableError when notify_current_task raises error' do
          allow(job).to receive(:notify_current_task).and_raise(LittleMonster::APIUnreachableError, 'api down')
          expect { job.run }.to raise_error(LittleMonster::APIUnreachableError)
        end

        it 'raises APIUnreachableError when notify_status raises error' do
          allow(job).to receive(:notify_status).and_raise(LittleMonster::APIUnreachableError, 'api down')
          expect { job.run }.to raise_error(LittleMonster::APIUnreachableError)
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
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
          allow_any_instance_of(MockJob::TaskA).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
          allow(job).to receive(:cancel)
          job.run
          expect(job).to have_received(:cancel).with(LittleMonster::CancelError).once
        end
      end
    end

    context 'on finish' do
      it 'notifies status as finished and passes output' do
        allow(job).to receive(:notify_status)
        job.run
        expect(job).to have_received(:notify_status).with(:finished, output: job.instance_variable_get('@output')).once
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
        job.instance_variable_set '@current_task', :task_a
        job.instance_variable_set '@retries', 4
      end

      it 'increases retries by 1' do
        job.send :do_retry rescue nil
        expect(job.instance_variable_get('@retries')).to eq(5)
      end

      it 'raises JobRetryError'  do
        expect { job.send :do_retry }.to raise_error(LittleMonster::JobRetryError)
      end

      it 'notifies status to pending' do
        allow(job).to receive(:notify_status)
        job.send :do_retry rescue nil
        expect(job).to have_received(:notify_status).with(:pending)
      end

      it 'notifies current task to pending and set retries' do
        allow(job).to receive(:notify_current_task)
        job.send :do_retry rescue nil
        expect(job).to have_received(:notify_current_task).with(job.current_task, :pending, retries: job.retries)
      end
    end


    context 'if max retries is reached' do
      before :each do
        allow(job).to receive(:abort_job)
        MockJob.retries 5
        job.instance_variable_set '@retries', 5
      end

      it 'aborts job' do
        job.send :do_retry
        expect(job).to have_received(:abort_job).with(LittleMonster::MaxRetriesError)
      end

      it 'does not retry' do
        allow(LittleMonster::JobRetryError).to receive(:new)
        job.send :do_retry
        expect(LittleMonster::JobRetryError).not_to have_received(:new)
      end
    end
  end

  describe 'notifiers' do
    let(:response) { double(success?: false) }

    before :each do
      allow(LittleMonster::API).to receive(:post).and_return(response)
      allow(LittleMonster::API).to receive(:get).and_return(response)
      allow(LittleMonster::API).to receive(:put).and_return(response)
    end

    describe '#notify_task_list' do
      context 'when should_request is false' do
        it 'returns true' do
          expect(job.send(:notify_task_list)).to be true
        end

        it 'does not send any request' do
          job.send(:notify_task_list)
          expect(LittleMonster::API).not_to have_received(:post)
        end
      end

      context 'when should_request is true' do
        before :each do
          allow(job).to receive(:should_request?).and_return(true)
        end

        it 'makes a request to api with task list, critical, retries and retry wait' do
          tasks_name_with_order = [{ name: :task_a, order: 0 }, { name: :task_b, order: 1 }]
          job.send(:notify_task_list)
          expect(LittleMonster::API).to have_received(:post).with("/jobs/#{job.id}/tasks",
                                                                  body: { tasks: tasks_name_with_order },
                                                                  retries: LittleMonster.job_requests_retries,
                                                                  retry_wait: LittleMonster.job_requests_retry_wait,
                                                                  critical: true).once
        end

        it 'returns request success?' do
          expect(job.send(:notify_task_list)).to eq(response.success?)
        end
      end
    end

    describe '#is_cancelled?' do
      context 'when should_request is false' do
        it 'returns false' do
          expect(job.send(:is_cancelled?)).to be false
        end

        it 'does not send any request' do
          job.send(:is_cancelled?)
          expect(LittleMonster::API).not_to have_received(:get)
        end
      end

      context 'when should_request is true' do
        before :each do
          allow(job).to receive(:should_request?).and_return(true)
        end

        it 'makes a request to api' do
          job.send(:is_cancelled?)
          expect(LittleMonster::API).to have_received(:get).with("/jobs/#{job.id}")
        end

        context 'if request was successful' do
          before :each do
            allow(response).to receive(:success?).and_return(true)
          end

          it 'returns true if response cancel is true' do
            allow(response).to receive(:body).and_return(cancel: true)
            expect(job.send(:is_cancelled?)).to be true
          end

          it 'returns false if response cancel is false' do
            allow(response).to receive(:body).and_return(cancel: false)
            expect(job.send(:is_cancelled?)).to be false
          end
        end

        context 'if request was not succesful' do
          before :each do
            allow(response).to receive(:success?).and_return(false)
          end

          it 'returns false' do
            expect(job.send(:is_cancelled?)).to be false
          end
        end
      end
    end

    describe '#notify_status' do
      context 'given a status and options' do
        let(:status) { :finished }
        let(:options) { { output: double } }

        context 'when should_request is false' do
          it 'returns true' do
            expect(job.send(:notify_status, status, options)).to be true
          end

          it 'does not send any request' do
            job.send(:notify_status, status, options)
            expect(LittleMonster::API).not_to have_received(:put)
          end
        end

        context 'when should_request is true' do
          before :each do
            allow(job).to receive(:should_request?).and_return(true)
          end

          it 'makes a request to api with status, options, critial, retries and retry wait' do
            job.send(:notify_status, status, options)
            expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}",
                                                                   body: { status: status }.merge(options),
                                                                   retries: LittleMonster.job_requests_retries,
                                                                   retry_wait: LittleMonster.job_requests_retry_wait,
                                                                   critical: true).once
          end

          it 'returns request success?' do
            expect(job.send(:notify_status, status, options)).to eq(response.success?)
          end
        end
      end
    end

    describe '#notify_current_task' do
      context 'given a task, status and options' do
        let(:task) { :task }
        let(:status) { :finished }
        let(:options) { { retries: 5 } }

        context 'when should_request is false' do
          it 'returns true' do
            expect(job.send(:notify_current_task, task, status, options)).to be true
          end

          it 'does not send any request' do
            job.send(:notify_current_task, task, status, options)
            expect(LittleMonster::API).not_to have_received(:put)
          end
        end

        context 'when should_request is true' do
          before :each do
            allow(job).to receive(:should_request?).and_return(true)
          end

          it 'makes a request to api with status, options, critical, retries and retry wait' do
            job.send(:notify_current_task, task, status, options)
            expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}/tasks/#{task}",
                                                                   body: { task: { status: status }.merge(options) },
                                                                   retries: LittleMonster.task_requests_retries,
                                                                   retry_wait: LittleMonster.task_requests_retry_wait,
                                                                   critical: true).once
          end

          it 'returns request success?' do
            expect(job.send(:notify_current_task, task, status, options)).to eq(response.success?)
          end
        end
      end
    end
  end

  describe '#should_request?' do
    it 'returns false if class is mock and env is test' do
      allow(job).to receive(:mock?).and_return(true)
      allow(LittleMonster.env).to receive(:test?).and_return(true)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns false if class is not mock and env is test' do
      allow(job).to receive(:mock?).and_return(false)
      allow(LittleMonster.env).to receive(:test?).and_return(true)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns false if class is mock and env is not test' do
      allow(job).to receive(:mock?).and_return(true)
      allow(LittleMonster.env).to receive(:test?).and_return(false)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns true if class is not mock and env is not test' do
      allow(job).to receive(:mock?).and_return(false)
      allow(LittleMonster.env).to receive(:test?).and_return(false)
      expect(job.send(:should_request?)).to be true
    end
  end
end
