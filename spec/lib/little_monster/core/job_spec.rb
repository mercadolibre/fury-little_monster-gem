require 'spec_helper'

RSpec::Matchers.define :job_data_with_hash do |x|
  match { |actual| actual == x }
end

describe LittleMonster::Core::Job do
  after :each do
    load './spec/mock/mock_job.rb'
  end

  let(:options) do
    {
      id: 0,
      tags: { a: :b }
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

    describe '::callback_max_retries' do
      let(:retries) { 5 }

      it 'sets the callback_max_retries class level instance variable' do
        job_class.callback_retries(retries)
        expect(job_class.callback_max_retries).to eq(retries)
      end
    end
  end

  describe '#initialize' do
    context 'given a full options hash' do
      let(:options) do
        {
          id: 1,
          tags: { tag: 'a tag' },
          retries: 2,
          current_action: :task_a,
          data: { outputs: { a: :b }, owners: { c: :d } },
          error: { message: 'message', retry: 2, type: 'type' }
        }
      end

      it { expect(job.id).to eq(options[:id]) }
      it { expect(job.tags).to eq(options[:tags]) }
      it { expect(job.retries).to eq(options[:retries]) }
      it { expect(job.current_action).to eq(options[:current_action]) }
      it { expect(job.data).to eq(LittleMonster::Core::Job::Data.new(nil, options[:data])) }
      it { expect(job.error).to eq(options[:error]) }
    end

    context 'given empty options' do
      let(:options) { {} }

      it { expect(job.id).to be_nil }
      it { expect(job.tags).to eq({}) }
      it { expect(job.retries).to eq(0) }
      it { expect(job.current_action).to eq(job.class.tasks.first) }
      it { expect(job.data).to be_instance_of(LittleMonster::Core::Job::Data) }
      it { expect(job.error).to eq({}) }
    end

    it 'sets status to pending' do
      expect(job.status).to eq(:pending)
    end

    it 'freezes the tags' do
      expect(job.tags.frozen?).to be true
    end

    it 'creates a new orchrestator' do
      expect(job.orchrestator).to be_instance_of(LittleMonster::Core::Job::Orchrestator)
    end
  end

  describe '#run' do
    it 'calls run on orchrestator' do
      allow(job.orchrestator).to receive(:run)
      job.run
      expect(job.orchrestator).to have_received(:run)
    end
  end

  describe 'notifiers' do
    let(:response) { double(success?: false) }

    before :each do
      allow(LittleMonster::API).to receive(:post).and_return(response)
      allow(LittleMonster::API).to receive(:get).and_return(response)
      allow(LittleMonster::API).to receive(:put).and_return(response)
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
        let(:options) { { cancel: true } }
        let(:response) { double }

        before :each do
          allow(job).to receive(:notify_job).and_return(response)
        end

        it 'calls notify_job with status, params and options' do
          job.notify_status options
          expect(job).to have_received(:notify_job).with({ body: { status: job.status }.merge(options) },
                                                         retries: LittleMonster.job_requests_retries,
                                                         retry_wait: LittleMonster.job_requests_retry_wait).once
        end

        it 'returns notify_job response' do
          expect(job.send(:notify_status)).to eq(response)
        end
      end
    end

    describe '#notify_callback' do
      context 'given a callback, status and options' do
        let(:status) { :pending }
        let(:options) { { retries: 1 } }
        let(:response) { double(success?: true) }

        before :each do
          allow(LittleMonster::API).to receive(:put).and_return(response)
        end

        context 'if should_request?' do
          before :each do
            allow(job).to receive(:should_request?).and_return(true)
          end

          context 'if options does not contain exception' do
            it 'makes a request to api with current_action and status merged with options' do
              job.notify_callback status, options
              expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}/callbacks/#{job.current_action}",
                                                                     { body: { name: job.current_action,
                                                                               status: status }.merge(options) },
                                                                     retries: LittleMonster.job_requests_retries,
                                                                     retry_wait: LittleMonster.job_requests_retry_wait).once
            end
          end

          context 'if options contains exception' do
            let(:serialized_error) { { message: 'message', type: 'type', retry: 2 } }

            before :each do
              options[:exception] = double
              allow(job).to receive(:serialize_error).and_return(serialized_error)
            end

            it 'makes a request to api with current_action and status merged with options' do
              job.notify_callback status, options
              expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}/callbacks/#{job.current_action}",
                                                                     { body: { name: job.current_action,
                                                                               status: status,
                                                                               exception: serialized_error }.merge(options.except(:exception)) },
                                                                     retries: LittleMonster.job_requests_retries,
                                                                     retry_wait: LittleMonster.job_requests_retry_wait).once
            end
          end

          it 'returns request success?' do
            expect(job.notify_callback  status, options).to eq(response.success?)
          end
        end
      end
    end

    describe '#notify_task' do
      context 'given a task, status and options' do
        let(:status) { :success }
        let(:options) { { retries: 5 } }
        let(:response) { double }

        before :each do
          allow(job).to receive(:notify_job).and_return(response)
        end

        context 'if options does not contain data and exception' do
          it 'makes a request to api with current_action, status, options, critical, retries and retry wait' do
            job.notify_task status, options
            expect(job).to have_received(:notify_job).with({ body: { tasks: [{ name: job.current_action,
                                                                               status: status }.merge(options)] } },
                                                           retries: LittleMonster.task_requests_retries,
                                                           retry_wait: LittleMonster.task_requests_retry_wait).once
          end
        end

        context 'if options contains data' do
          before :each do
            options[:data] = double
          end

          it 'makes a request to api with current_action, status, options, critical, retries, retry wait and sets data to body' do
            job.notify_task status, options
            expect(job).to have_received(:notify_job).with({ body: { data: options[:data],
                                                                     tasks: [{ name: job.current_action,
                                                                               status: status }
                                                                                  .merge(options.except(:data))] } },
                                                           retries: LittleMonster.task_requests_retries,
                                                           retry_wait: LittleMonster.task_requests_retry_wait).once
          end
        end

        context 'if options contains exception' do
          let(:serialized_error) { { message: 'message', type: 'type', retry: 2 } }

          before :each do
            options[:exception] = double
            allow(job).to receive(:serialize_error).and_return(serialized_error)
          end


          it 'makes a request to api with current_action, status, options, critical, retries, retry wait and sets serialized error to body' do
            job.notify_task status, options
            expect(job).to have_received(:notify_job).with({ body: { tasks: [{ name: job.current_action,
                                                                               status: status,
                                                                               exception: serialized_error }
                                                                                 .merge(options.except(:exception))] } },
                                                           retries: LittleMonster.task_requests_retries,
                                                           retry_wait: LittleMonster.task_requests_retry_wait).once
          end
        end

        it 'returns request success?' do
          expect(job.notify_task status, options).to eq(response)
        end
      end
    end
  end

  describe '#notify_job' do
    let(:response) { double(success?: true) }

    before :each do
      allow(LittleMonster::API).to receive(:put).and_return(response)
    end

    context 'when should_request is false' do
      it 'returns true' do
        expect(job.send(:notify_job)).to be true
      end

      it 'does not send any request' do
        job.send(:notify_job)
        expect(LittleMonster::API).not_to have_received(:put)
      end
    end

    context 'when should_request is true' do
      let(:params) { { body: {} } }
      let(:options) { { retries: 5 } }

      before :each do
        allow(job).to receive(:should_request?).and_return(true)
      end

      it 'makes a request to api with params body with data and options merged with critical' do
        job.send(:notify_job, params, options)
        expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}", params, options.merge(critical: true)).once
      end

      context 'if options contains data' do
        before :each do
          params[:body][:data] = job.data.to_h
        end

        it 'makes request with data as a hash' do
          job.send(:notify_job, params, options)
          expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}", { body: hash_including(data: job.data.to_h) } , any_args).once
        end
      end

      context 'if options does not contain data' do
        before :each do
          params[:body].delete(:data)
        end

        it 'makes request without data' do
          job.send(:notify_job, params, options)
          expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job.id}", params, options).once
        end
      end

      it 'returns request success?' do
        expect(job.send(:notify_job, params, options)).to eq(response.success?)
      end
    end
  end

  describe '#should_request?' do
    it 'returns false if class is mock and disable_requests is true' do
      allow(job).to receive(:mock?).and_return(true)
      allow(LittleMonster).to receive(:disable_requests?).and_return(true)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns false if class is not mock and disable_requests is true' do
      allow(job).to receive(:mock?).and_return(false)
      allow(LittleMonster).to receive(:disable_requests?).and_return(true)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns false if class is mock and disable_requests is false' do
      allow(job).to receive(:mock?).and_return(true)
      allow(LittleMonster).to receive(:disable_requests?).and_return(false)
      expect(job.send(:should_request?)).to be false
    end

    it 'returns true if class is not mock and disable_requests is false' do
      allow(job).to receive(:mock?).and_return(false)
      allow(LittleMonster).to receive(:disable_requests?).and_return(false)
      expect(job.send(:should_request?)).to be true
    end
  end

  describe '#tasks_to_run' do
    context 'if callback is running' do
      before :each do
        job.current_action = :on_success
      end

      it 'returns []' do
        expect(job.tasks_to_run).to eq([])
      end
    end

    context 'if callback is not running' do
      context 'if job has no current_action' do
        before :each do
          job.current_action = nil
        end

        it 'returns []' do
          expect(job.tasks_to_run).to eq([])
        end
      end

      context 'if job has current_action' do
        before :each do
          job.current_action = :task_b
        end

        it 'returns array sliced from current task to end' do
          expect(job.tasks_to_run).to eq([:task_b, :task_c])
        end
      end
    end
  end

  describe '#callback_to_run' do
    it 'returns on_success if status is success' do
      job.status = :success
      expect(job.callback_to_run).to eq(:on_success)
    end

    it 'returns on_error if status is error' do
      job.status = :error
      expect(job.callback_to_run).to eq(:on_error)
    end

    it 'returns on_cancel if status is cancelled' do
      job.status = :cancelled
      expect(job.callback_to_run).to eq(:on_cancel)
    end

    it 'returns nil if status is anything else' do
      job.status = :running
      expect(job.callback_to_run).to be_nil
    end
  end

  describe 'callback_running?' do
    it 'returns false if current_action is nil' do
      job.current_action = nil
      expect(job.callback_running?).to be false
    end

    it 'returns true if current_action is included in task list' do
      job.current_action = job.class.tasks.first
      expect(job.callback_running?).to be false
    end

    it 'return false if current_action neither a task nor callback' do
      job.current_action = :non_existing_task
      expect(job.callback_running?).to be false
    end

    it 'returns true if current_action is included in CALLBACKS' do
      described_class::CALLBACKS.each do |callback|
        job.current_action = callback
        expect(job.callback_running?).to be true
      end
    end
  end

  describe 'serialize_error' do
    context 'given an error' do
      let(:error) { StandardError.new 'boooom' }

      it 'returns a hash with message, type and current retry' do
        expect(job.serialize_error error).to eq(message: error.message, type: error.class.to_s, retry: job.retries)
      end
    end
  end

  describe '#max_retries' do
    let(:retries) { double }

    context 'if callback is not running' do
      before :each do
        allow(job).to receive(:callback_running?).and_return(false)
      end

      it 'returns class max retries' do
        allow(job.class).to receive(:max_retries).and_return(retries)
        expect(job.max_retries).to eq(retries)
      end
    end

    context 'if callback is running' do
      before :each do
        allow(job).to receive(:callback_running?).and_return(true)
      end

      it 'returns class callback max retries' do
        allow(job.class).to receive(:callback_max_retries).and_return(retries)
        expect(job.max_retries).to eq(retries)
      end
    end
  end

  describe '#retry?' do
    context 'is mock is false' do
      before :each do
        allow(job).to receive(:mock?).and_return(false)
      end

      it 'returns true if max_retries is -1' do
        allow(job).to receive(:max_retries).and_return(-1)
        expect(job.retry?).to be true
      end

      it 'returns true if max_retries is greater than retries' do
        r = 3
        allow(job).to receive(:max_retries).and_return(r)
        job.retries = r - 1
        expect(job.retry?).to be true
      end

      it 'returns false if retries than max_retries' do
        r = 3
        allow(job).to receive(:max_retries).and_return(r)
        job.retries = r + 1
        expect(job.retry?).to be false
      end
    end

    context 'if mock is true' do
      before :each do
        allow(job).to receive(:mock?).and_return(true)
      end

      it 'returns false' do
        expect(job.retry?).to be false
      end
    end
  end
end
