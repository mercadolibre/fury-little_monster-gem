require 'spec_helper'

describe LittleMonster::RSpec::TaskHelper do
  let(:job_options) do
    {
      id: 0,
      params: { a: 'b' }
    }
  end

  let(:job) { MockJob.new job_options }

  let(:task_class) { MockJob::Task }
  let(:options) do
    {
      params: { a: :b },
      data: LittleMonster::Core::Job::Data.new(job)
    }
  end

  let(:task_helper) do
    class Dummy
      extend LittleMonster::RSpec::TaskHelper
    end
  end

  describe described_class::Result do
    let(:task_instance) { double(run: double, data: options[:data]) }
    let!(:result) { described_class.new task_instance }

    describe '#initialize' do
      it 'sets task variable' do
        expect(result.instance_variable_get '@task').to eq(task_instance)
      end

      it 'calls run on task' do
        expect(task_instance).to have_received(:run)
      end
    end

    specify { expect(result.instance).to eq(task_instance) }
    specify { expect(result.data).to eq(task_instance.data) }
  end

  describe '::run_task' do
    context 'given a task and an options hash' do
      it 'calls generate_task' do
        allow(task_helper).to receive(:generate_task)
        allow(described_class::Result).to receive(:new)
        options = { a: :b , c: :d }
        task_helper.run_task task_class, options
        expect(task_helper).to have_received(:generate_task).with(task_class, options).once
      end

      it 'returns result' do
        expect(run_task(task_class, options).class).to eq described_class::Result
      end
    end
  end

  describe '::generate_task' do
    context 'given a task and an options hash' do
      context 'when task is class' do
        it 'builds an instance from task_class' do
          allow(task_class).to receive(:new).and_call_original
          generate_task task_class
          expect(task_class).to have_received(:new)
        end
      end

      context 'when task is symbol' do
        it 'builds an instance from task_class' do
          allow(task_class).to receive(:new).and_call_original
          generate_task task_class.to_s.underscore.to_sym
          expect(task_class).to have_received(:new)
        end
      end

      it 'returns a task result instance' do
        expect(generate_task(task_class).class).to eq(task_class)
      end

      context 'returns task instance' do
        let(:task) { generate_task(task_class, options) }

        it 'has preveious data key from options' do
          expect(task.data).to eq(options[:data])
        end

        it 'has cancelled_callback to true if cancelled is true' do
          options[:cancelled] = true
          expect { task.is_cancelled! }.to raise_error(LittleMonster::CancelError)
        end

        it 'has job_id' do
          options[:job_id] = 5
          expect(task.job_id).to eq(options[:job_id])
        end

        it 'has job_retries' do
          options[:job_retries] = 5
          expect(task.job_retries).to eq(options[:job_retries])
        end

        it 'has job_max_retries' do
          options[:job_max_retries] = 12
          expect(task.job_max_retries).to eq(options[:job_max_retries])
        end

        it 'has last_retry? to true' do
          options[:last_retry] = true
          expect(task.last_retry?).to be true
        end

        it 'has last_retry? to false by default' do
          expect(task.last_retry?).to be false
        end
      end
    end
  end
end
