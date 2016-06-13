require 'spec_helper'

describe LittleMonster::RSpec::TaskHelper do
  let(:task_class) { MockJob::Task }
  let(:options) do
    {
      params: { a: :b },
      previous_output: { c: :d }
    }
  end

  describe '::run_task' do
    context 'given a task and an options hash' do
      it 'builds an instance from task_class' do
        allow(task_class).to receive(:new).and_call_original
        run_task task_class
        expect(task_class).to have_received(:new)
      end

      it 'calls perform on instance' do
        task_double = instance_double task_class
        allow(task_double).to receive(:perform)
        allow(task_class).to receive(:new).and_return(task_double)

        run_task task_class

        expect(task_double).to have_received(:perform)
      end

      it 'returns instance' do
        expect(run_task(task_class).class).to eq(task_class)
      end

      context 'returned task instance' do
        let(:task) { run_task task_class, options }

        it 'has params key from options' do
          expect(task.params).to eq(options[:params])
        end

        it 'has preveious output key from options' do
          expect(task.previous_output).to eq(options[:previous_output])
        end

        it 'has cancelled_callback to true if cancelled is true' do
          options[:cancelled] = true
          expect { task.is_cancelled! }.to raise_error(LittleMonster::CancelError)
        end
      end
    end
  end
end
