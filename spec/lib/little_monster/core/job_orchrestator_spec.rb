require 'spec_helper'

describe LittleMonster::Core::Job::Orchrestator do
  subject { MockJob.new({}).orchrestator }

  describe '#initialize' do
    context 'given a job instance' do
      it 'sets job instance variable'
      it 'sets parent_logger to job logger'
    end
  end

  describe 'run' do
    it 'notifies job status as running'
    it 'runs tasks'
    it 'runs callbacks'
    it 'ensures that job status is notified'

    context 'when api is down' do
      it 'raises APIUnreachableError when notify_status raises error' do
        allow(subject.job).to receive(:notify_status).and_raise(LittleMonster::APIUnreachableError, 'api down')
        expect { subject.run }.to raise_error(LittleMonster::APIUnreachableError)
      end
    end

    context 'integration'
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

          context 'if task ended successfully' do
            it 'notifies api task ended with status success and data' do
              allow(subject.job).to receive(:notify_current_task)
              subject.run_tasks
              expect(subject.job).to have_received(:notify_current_task).with(task_symbol, :success, data: subject.job.data)
            end
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
            subject.job.instance_variable_set '@current_task', :task_b
            subject.run_tasks
          end

          it 'does not build task_a' do
            expect(MockJob::TaskA).not_to have_received(:new)
          end

          it 'builds task_b' do
            expect(MockJob::TaskB).to have_received(:new)
          end
        end

        context 'and it does not have any current_task' do
          before :each do
            subject.job.instance_variable_set '@current_task', nil
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
  end

  context 'when api is down' do
    it 'raises APIUnreachableError when notify_current_task raises error' do
      allow(subject.job).to receive(:notify_current_task).and_raise(LittleMonster::APIUnreachableError, 'api down')
      expect { subject.run_tasks }.to raise_error(LittleMonster::APIUnreachableError)
    end
  end

  context 'if job is cancelled' do
    before :each do
      allow(subject).to receive(:cancel)
    end

    it 'calls cancel' do
      allow(subject.job).to receive(:is_cancelled?).and_return(true)
      subject.run_tasks
      expect(subject).to have_received(:cancel).with(LittleMonster::CancelError).once
    end

    context 'and task is running' do
      it 'raises CancelError' do
        allow_any_instance_of(MockJob::TaskA).to receive(:run).and_call_original
        allow_any_instance_of(MockJob::TaskA).to receive(:is_cancelled!).and_raise(LittleMonster::CancelError)
        subject.run_tasks
        expect(subject).to have_received(:cancel).with(LittleMonster::CancelError).once
      end
    end
  end

  context 'after running all tasks successfuly' do
    it 'sets current_task to nil' do
      subject.run_tasks
      expect(subject.job.current_task).to be_nil
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

      it 'notifies callback as running' do
        subject.run_callback
        expect(subject.job).to have_received(:notify_callback).with(callback, :running)
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
          expect(subject.job).to have_received(:notify_callback).with(callback, :success)
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

    it 'calls set_default_values on task with data, job_id, logger, and is_cancelled method' do
      task = task_class.new({})
      allow(task).to receive(:set_default_values)
      allow(task_class).to receive(:new).and_return(task)
      subject.build_task task_symbol
      expect(task).to have_received(:set_default_values).with(subject.job.data, subject.job.id, subject.logger, subject.job.method(:is_cancelled?))
    end

    it 'returns the built task' do
      task = task_class.new({})
      allow(task_class).to receive(:new).and_return(task)
      expect(subject.build_task task_symbol).to eq(task)
    end
  end

  describe 'abort_job'
  describe 'cancel'
  describe 'handle_error'
  describe 'do_retry'
end
