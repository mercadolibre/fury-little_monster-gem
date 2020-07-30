require 'spec_helper'

describe LittleMonster::Core::Job::Orchrestator do
  subject { MockJob.new({}).orchrestator }

  before :each do
    MockJob.instance_variable_set '@mock', false
  end

  describe '#initialize' do
    context 'given a job instance' do
      it 'sets job instance variable' do
        expect(subject.job).not_to be_nil
      end

      it 'sets logger to job logger' do
        expect(subject.logger).to eq(subject.job.logger)
      end
    end
  end

  describe 'run' do
    before :each do
      allow(subject.job).to receive(:notify_status)
    end

    context 'before start' do
      before :each do
        allow(subject.job).to receive(:status=)
        allow(subject).to receive(:run_tasks)
        allow(subject).to receive(:run_callback)
      end

      it 'sets status as running' do
        subject.run
        expect(subject.job).to have_received(:status=).with(:running).once
      end

      context 'if job has a finishing status' do
        let(:status) { :error }
        before :each do
          subject.job.instance_variable_set '@status', status
        end

        it 'resets status after setting status running' do
          subject.run
          expect(subject.job).to have_received(:status=).with(:running).ordered
          expect(subject.job).to have_received(:status=).with(status).ordered
        end

        it 'does not run tasks' do
          subject.run
          expect(subject).not_to have_received(:run_tasks)
        end
      end

      context 'if job does not have a finishing status' do
        it 'resets status after setting status running' do
          subject.run
          expect(subject.job).to have_received(:status=).once
        end
      end

      it 'runs tasks' do
        subject.run
        expect(subject).to have_received(:run_tasks).once
      end

      it 'resets retries after running tasks' do
        subject.job.retries = 10
        allow(subject.job).to receive(:retries=).and_call_original
        subject.run
        expect(subject).to have_received(:run_tasks).ordered
        expect(subject.job).to have_received(:retries=).with(0).ordered
      end
    end

    it 'runs callback' do
      allow(subject).to receive(:run_callback)
      subject.run
      expect(subject).to have_received(:run_callback).once
    end

    it 'notifies status twice' do
      subject.run
      expect(subject.job).to have_received(:notify_status).twice
    end

    it 'ensures that job status is notified' do
      allow(subject).to receive(:run_tasks).and_raise(StandardError, 'boom')
      subject.run rescue
      expect(subject.job).to have_received(:notify_status).twice
    end

    context 'if job has ended status at the end of run' do
      it 'notifies status with data' do
        subject.run
        expect(subject.job).to have_received(:notify_status).with(data: subject.job.data).once
      end
    end

    context 'if job does not have ended status at the end of run' do
      it 'notifies status with data' do
        allow(subject).to receive(:run_tasks)
        allow(subject).to receive(:run_callback)
        subject.run
        expect(subject.job).to have_received(:notify_status).with({}).once
      end
    end

    context 'when api is down' do
      it 'raises APIUnreachableError when notify_status raises error' do
        allow(subject.job).to receive(:notify_status).and_raise(LittleMonster::APIUnreachableError, 'api down')
        expect { subject.run }.to raise_error(LittleMonster::APIUnreachableError)
      end
    end

    context 'integration' do
      context 'if all tasks and callbacks pass' do
        it 'ends with status success' do
          subject.run
          expect(subject.job.status).to eq(:success)
        end

        it 'runs on_success callback' do
          allow(subject.job).to receive(:on_success)
          subject.run
          expect(subject.job).to have_received(:on_success)
        end

        context 'if job callback fails' do
          before :each do
            allow(subject.job).to receive(:on_success).and_raise(StandardError, 'boom')
          end

          context 'and has retries left' do
            it 'raises JobRetryError' do
              expect { subject.run }.to raise_error(LittleMonster::JobRetryError)
            end
          end

          context 'and has no retries left' do
            before :each do
              allow(subject.job).to receive(:retry?).and_return(false)
            end

            it 'raises CallbackFailedError' do
              expect { subject.run }.to raise_error(LittleMonster::CallbackFailedError)
            end
          end
        end
      end

      context 'if a task fail and has retries left' do
        before :each do
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_raise(LittleMonster::TaskError, 'error')
        end

        it 'raises a job retry error' do
          expect { subject.run }.to raise_error(LittleMonster::JobRetryError)
        end

        it 'does not run any callback' do
          allow(subject).to receive(:run_callback)
          subject.run rescue
          expect(subject).not_to have_received(:run_callback)
        end
      end

      context 'if a task fails and has no retries left' do
        before :each do
          subject.job.retries = subject.job.max_retries
          allow_any_instance_of(MockJob::TaskA).to receive(:run).and_raise(LittleMonster::TaskError, 'error')
        end

        it 'ends with status error' do
          subject.run
          expect(subject.job.status).to eq(:error)
        end

        it 'runs on_error callback' do
          allow(subject.job).to receive(:on_error)
          subject.run
          expect(subject.job).to have_received(:on_error)
        end

        context 'if on_error fails' do
          context 'and has retries left' do
            it 'raises JobRetryError' do
              allow(subject.job).to receive(:on_error).and_raise(StandardError, 'boom')
              expect { subject.run }.to raise_error(LittleMonster::JobRetryError)
            end
          end

          context 'and has no retries left' do
            before :each do
              allow(subject.job).to receive(:retry?).and_return(false)
            end

            it 'ends with status error' do
              subject.run
              expect(subject.job.status).to eq(:error)
            end
          end
        end
      end
    end
  end

  describe 'run_tasks' do
    context 'on mock job' do
      context 'for each task' do
        MockJob.tasks.each do |task_symbol|
          it 'calls build_task with task_symbol' do
            allow(subject).to receive(:build_task).and_call_original
            subject.run_tasks
            expect(subject).to have_received(:build_task).with(task_symbol)
          end

          it 'calls run on task' do
            task_dummy = double(run: nil)
            allow(subject).to receive(:build_task).and_call_original
            allow(subject).to receive(:build_task).with(task_symbol).and_return(task_dummy)

            subject.run_tasks
            expect(task_dummy).to have_received(:run)
          end

          it 'sets current action' do
            allow(subject.job).to receive(:current_action=).and_call_original
            subject.run_tasks
            expect(subject.job).to have_received(:current_action=).with(task_symbol)
          end
        end

        context 'if tasks ended successfully' do
          it 'notifies api task ended with status success and data for each task' do
            allow(subject.job).to receive(:notify_task)
            subject.run_tasks
            expect(subject.job).to have_received(:notify_task).with(:success, data: subject.job.data).exactly(MockJob.tasks.count).times
          end
        end
      end

      context 'if run is from rebuild' do
        before :each do
          MockJob.tasks.each do |task_symbol|
            allow(MockJob.task_class_for task_symbol).to receive(:new).and_call_original
          end
        end

        context 'and it already ran task_a' do
          before :each do
            subject.job.current_action = :task_b
            subject.run_tasks
          end

          it 'does not build task_a' do
            expect(MockJob::TaskA).not_to have_received(:new)
          end

          it 'builds task_b' do
            expect(MockJob::TaskB).to have_received(:new)
          end

          it 'builds task_c' do
            expect(TaskC).to have_received(:new)
          end
        end

        context 'and it does not have any current_action' do
          before :each do
            subject.job.current_action = nil
            subject.run_tasks
          end

          it 'does not build task_a' do
            expect(MockJob::TaskA).not_to have_received(:new)
          end

          it 'does not build task_b' do
            expect(MockJob::TaskB).not_to have_received(:new)
          end
        end
      end
    end

    context 'if task_name does not exists' do
      it 'sets status as error' do
        allow(subject.job).to receive(:tasks_to_run).and_return(Array(:non_existing_task))

        subject.run_tasks
        expect(subject.job.status).to eq(:error)
      end
    end

    context 'when a task fails' do
      context 'when task.on_error does not fail' do
        let(:mock_task) { MockJob::TaskB.new({}) }
        let(:error) { StandardError.new 'error' }

        before :each do
          allow(subject).to receive(:handle_error)
          allow(MockJob::TaskB).to receive(:new).and_return(mock_task)
          allow(mock_task).to receive(:run).and_raise(error)
          allow(mock_task).to receive(:error)
        end

        it 'calls handle_error with error' do
          subject.run_tasks
          expect(subject).to have_received(:handle_error).with(error)
        end

        it 'calls error callback on task unless there is a name error' do
          subject.run_tasks
          expect(mock_task).to have_received(:error).with(error)
        end

        it 'does not call error callback on task if there is a name error' do
          allow(mock_task).to receive(:run).and_raise(NameError, 'name error')
          subject.run_tasks
          expect(mock_task).not_to have_received(:error)
        end
      end

      context 'when task.on_error fails' do
        let(:mock_task) { MockJob::TaskB.new({}) }
        let(:error) { StandardError.new 'error' }
        let(:task_error) { StandardError.new 'another_error' }

        before :each do
          allow(subject).to receive(:handle_error)
          allow(MockJob::TaskB).to receive(:new).and_return(mock_task)
          allow(mock_task).to receive(:run).and_raise(error)
          allow(mock_task).to receive(:error).and_raise(task_error)
        end

        it 'calls handle_error with task_error' do
          subject.run_tasks
          expect(subject).to have_received(:handle_error).with(task_error)
        end

        it 'calls error callback on task unless there is a name error' do
          subject.run_tasks
          expect(mock_task).to have_received(:error).with(error)
        end

        it 'does not call error callback on task if there is a name error' do
          allow(mock_task).to receive(:run).and_raise(NameError, 'name error')
          subject.run_tasks
          expect(mock_task).not_to have_received(:error)
        end
      end
    end
  end

  context 'when api is down' do
    it 'raises APIUnreachableError when notify_task raises error' do
      allow(subject.job).to receive(:notify_task).and_raise(LittleMonster::APIUnreachableError, 'api down')
      expect { subject.run_tasks }.to raise_error(LittleMonster::APIUnreachableError)
    end
  end

  context 'when ownership lost' do
    it 'raises OwnershipLostError' do
      allow(subject.job).to receive(:check_abort_cause).and_return(:ownership_lost)
      expect { subject.run_tasks }.to raise_error(LittleMonster::OwnershipLostError)
    end
  end

  context 'if job is cancelled' do
    before :each do
      allow(subject).to receive(:cancel)
    end

    it 'calls cancel' do
      allow(subject.job).to receive(:check_abort_cause).and_return(:cancel)
      subject.run_tasks
      expect(subject).to have_received(:cancel).once
    end

    context 'and task is running' do
      it 'raises CancelError' do
        allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
        allow_any_instance_of(MockJob::TaskA).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
        subject.run_tasks
        expect(subject).to have_received(:cancel).once
      end
    end
  end

  context 'after running all tasks successfuly' do
    it 'sets current_action to nil' do
      subject.run_tasks
      expect(subject.job.current_action).to be_nil
    end

    it 'sets current_action to nil' do
      subject.run_tasks
      expect(subject.job.current_action).to be_nil
    end

    it 'sets staus as success' do
      subject.run_tasks
      expect(subject.job.status).to eq(:success)
    end
  end

  describe 'run_callback' do
    context 'if job#callback_to_run is not nil' do
      let(:callback) { :on_success }

      before :each do
        allow(subject.job).to receive(:callback_to_run).and_return(callback)
        allow(subject.job).to receive(:notify_callback).and_call_original
      end

      it 'sets current action to job#callback_to_run' do
        allow(subject.job).to receive(:current_action=).and_call_original
        subject.run_callback
        expect(subject.job).to have_received(:current_action=).with(subject.job.callback_to_run)
      end

      it 'notifies callback as running' do
        subject.run_callback
        expect(subject.job).to have_received(:notify_callback).with(:running)
      end

      it 'runs callback on job' do
        allow(subject.job).to receive(callback)
        subject.run_callback
        expect(subject.job).to have_received(callback)
      end

      context 'if api is unreachable' do
        it 'raises an APIUnreachableError' do
          allow(subject.job).to receive(:notify_callback).and_raise(LittleMonster::APIUnreachableError)
          expect { subject.run_callback }.to raise_error(LittleMonster::APIUnreachableError)
        end
      end

      context 'if callback fails' do
        let(:error) { StandardError.new 'boom' }

        before :each do
          allow(subject.job).to receive(callback).and_raise(error)
        end

        it 'calls handle_error with error' do
          allow(subject).to receive(:handle_error)
          subject.run_callback rescue
          expect(subject).to have_received(:handle_error).with(error)
        end

        it 'does not notify_callback with status success' do
          subject.run_callback rescue
          expect(subject.job).not_to have_received(:notify_callback).with(callback, :success)
        end
      end

      context 'if callback finished succefully' do
        it 'notifies callback status as success' do
          subject.run_callback
          expect(subject.job).to have_received(:notify_callback).with(:success)
        end

        it 'sets current_action to nil' do
          subject.run_callback
          expect(subject.job.current_action).to be_nil
        end
      end
    end
  end

  describe 'build_task' do
    let(:task_class) { MockJob::TaskA }
    let(:task_symbol) { :task_a }

    it 'build a task_class with build_task method' do
      allow(task_class).to receive(:new).and_call_original
      subject.build_task task_symbol
      expect(MockJob::TaskA).to have_received(:new).with(subject.job.data)
    end

    it 'calls set_default_values on task with data, job_id, logger, is_cancelled method, retries and retry? method' do
      task = task_class.new({})
      allow(task).to receive(:set_default_values)
      allow(task_class).to receive(:new).and_return(task)
      subject.build_task task_symbol
      expect(task).to have_received(:set_default_values).with(data: subject.job.data,
                                                              job_id: subject.job.id,
                                                              job_logger: subject.logger,
                                                              cancelled_callback: subject.job.method(:is_cancelled?),
                                                              cancelled_throw_callback: subject.job.method(:is_cancelled!),
                                                              retries: subject.job.retries,
                                                              max_retries: subject.job.max_retries,
                                                              retry_callback: subject.job.method(:retry?))
    end

    it 'returns the built task' do
      task = task_class.new({})
      allow(task_class).to receive(:new).and_return(task)
      expect(subject.build_task task_symbol).to eq(task)
    end
  end

  describe '#abort_job' do
    let(:error) { LittleMonster::FatalTaskError.new }
    context 'if callback is running' do
      let(:callback) { :on_success }

      before :each do
        subject.job.current_action = callback
      end

      it 'calls notify_callback with status error' do
        allow(subject.job).to receive(:notify_callback)
        subject.abort_job error rescue
        expect(subject.job).to have_received(:notify_callback).with(:error, exception: error)
      end

      context 'if current_action is not on_error' do
        before :each do
          subject.job.current_action = :on_success
        end

        it 'sets status to pending' do
          subject.abort_job error rescue
          expect(subject.job.status).to eq(:pending)
        end

        it 'raises error' do
          expect { subject.abort_job error }.to raise_error(LittleMonster::CallbackFailedError)
        end

        context 'if current_action is on_error' do
          before :each do
            subject.job.current_action = :on_error
          end

          it 'sets status to error' do
            subject.abort_job error rescue
            expect(subject.job.status).to eq(:error)
          end

          it 'does not raise an error' do
            subject.abort_job error
          end
        end
      end
    end

    context 'if task is running' do
      before :each do
        subject.job.current_action = :task
      end

      it 'calls notify_task with status error' do
        allow(subject.job).to receive(:notify_task)
        subject.abort_job error
        expect(subject.job).to have_received(:notify_task).with(:error, exception: error)
      end
    end

    it 'sets status as error' do
      subject.abort_job error
      expect(subject.job.status).to eq(:error)
    end
  end

  describe '#cancel' do
    it 'notifies current_action status as cancelled' do
      allow(subject.job).to receive(:notify_task)
      subject.cancel
      expect(subject.job).to have_received(:notify_task).with(:cancelled)
    end

    it 'sets status as cancelled' do
      subject.cancel
      expect(subject.job.status).to eq(:cancelled)
    end
  end

  describe '#handle_error' do
    before :each do
      allow(subject).to receive(:do_retry)
      allow(subject).to receive(:abort_job)
    end

    context 'if env is development' do
      before :each do
        allow(LittleMonster.env).to receive(:development?).and_return(true)
      end

      it 'raises passed exception' do
        e = StandardError.new
        expect { subject.handle_error e }.to raise_error(e)
      end
    end

    context 'if env is not development' do
      before :each do
        allow(LittleMonster.env).to receive(:development?).and_return(false)
      end

      it 'does not abort if it did not receive a FatalTaskError' do
        allow(subject).to receive(:abort_job)
        subject.handle_error LittleMonster::TaskError.new
        expect(subject).not_to have_received(:abort_job)
      end

      it 'aborts if received a FatalTaskError' do
        subject.handle_error LittleMonster::FatalTaskError.new
        expect(subject).to have_received(:abort_job).with LittleMonster::FatalTaskError
      end

      it 'aborts if received a name error' do
        subject.handle_error NameError.new
        expect(subject).to have_received(:abort_job).with NameError
      end

      it 'calls do_retry if non FatalTaskError nor NameError' do
        error = LittleMonster::TaskError.new
        subject.handle_error error
        expect(subject).to have_received(:do_retry).with error
      end
    end
  end

  describe '#do_retry' do
    context 'given an error' do
      let(:error) { StandardError.new 'booom' }
      context 'if job retry is true' do
        before :each do
          allow(subject.job).to receive(:retry?).and_return(true)
        end

        it 'increases job retries by 1' do
          retries = subject.job.retries
          subject.do_retry(error) rescue nil
          expect(subject.job.retries).to eq(retries + 1)
        end

        it 'raises JobRetryError'  do
          expect { subject.do_retry(error) }.to raise_error(LittleMonster::JobRetryError)
        end

        it 'sets job status to pending' do
          subject.do_retry(error) rescue nil
          expect(subject.job.status).to eq(:pending)
        end

        context 'if task is running' do
          it 'notifies current task as pending and send retries and exception' do
            allow(subject.job).to receive(:notify_task)
            subject.do_retry(error) rescue nil
            expect(subject.job).to have_received(:notify_task).with(:pending, retries: subject.job.retries, exception: error)
          end
        end

        context 'if callback is running' do
          before :each do
            allow(subject.job).to receive(:callback_running?).and_return(true)
          end

          it 'notifies callback as pending and send retries and exception' do
            allow(subject.job).to receive(:notify_callback)
            subject.do_retry(error) rescue nil
            expect(subject.job).to have_received(:notify_callback).with(:pending, retries: subject.job.retries, exception: error)
          end
        end
      end

      context 'if job retry is false' do
        before :each do
          allow(subject).to receive(:abort_job)
          allow(subject.job).to receive(:retry?).and_return(false)
        end

        it 'aborts job' do
          subject.do_retry(error)
          expect(subject).to have_received(:abort_job).with(error)
        end

        it 'does not retry' do
          allow(LittleMonster::JobRetryError).to receive(:new)
          subject.do_retry(error)
          expect(LittleMonster::JobRetryError).not_to have_received(:new)
        end
      end
    end
  end
end
