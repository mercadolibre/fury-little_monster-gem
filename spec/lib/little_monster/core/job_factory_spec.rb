require 'spec_helper'

describe LittleMonster::Core::Job::Factory do
  let(:message) do
    {
      id: 0,
      name: :mock_job,
      data: { x: :y },
      tags: [{ a: :b }, { c: :d }]
    }
  end

  let(:worker_id) { LittleMonster::Core::WorkerId.new }
  let(:factory) { described_class.new worker_id, message }

  describe '#initialize' do
    it { expect(factory.instance_variable_get '@id').to eq(message[:id]) }
    it { expect(factory.instance_variable_get '@name').to eq(message[:name]) }
    it { expect(factory.instance_variable_get '@input_data').to eq(message[:data]) }
    it { expect(factory.instance_variable_get '@job_class').to eq(MockJob) }

    it 'fetches attributes from api' do
      allow_any_instance_of(described_class).to receive(:fetch_attributes).and_call_original
      expect(factory).to have_received(:fetch_attributes).once
    end

    it 'raises JobClassNotFoundError if job class does not exists' do
      message[:name] = 'not_existing_class'
      allow(LittleMonster::API).to receive(:put)
      expect { factory }.to raise_error(LittleMonster::JobClassNotFoundError)
    end

    it 'converts tags array to tags hash' do
      expect(factory.instance_variable_get '@tags').to eq(a: :b, c: :d)
    end

    it 'sets logger default_tags as @tags merged with id and job name' do
      tags = factory.instance_variable_get '@tags'
      expect(factory.logger.default_tags).to eq(tags.merge(id: message[:id], name: message[:name]))
    end
  end

  describe '#build' do
    before :each do
      allow(factory).to receive(:notify_job_task_list)
      allow(factory).to receive(:notify_job_max_retries)
    end

    it 'returns if discard? is true' do
      allow(factory).to receive(:discard?).and_return(true)
      expect(factory.build).to be_nil
    end

    it 'builds job class instance if discard? is false' do
      allow(factory).to receive(:discard?).and_return(false)
      allow(MockJob).to receive(:new).and_call_original
      factory.build
      expect(MockJob).to have_received(:new)
        .with(factory.job_attributes)
    end

    context 'when requests are enabled' do
      before :each do
        allow(LittleMonster).to receive(:disable_requests?).and_return(false)
        factory.build
      end

      it 'calls notify_job_max_retries' do
        expect(factory).to have_received(:notify_job_max_retries).once
      end

      it 'calls notify_job_task_list' do
        expect(factory).to have_received(:notify_job_task_list).once
      end
    end

    context 'when requests are disabled' do
      before :each do
        allow(LittleMonster).to receive(:disable_requests?).and_return(true)
        factory.build
      end

      it 'does not call notify_job_max_retries' do
        expect(factory).not_to have_received(:notify_job_max_retries)
      end

      it 'does not call notify_job_task_list' do
        expect(factory).not_to have_received(:notify_job_task_list)
      end
    end
  end

  describe '#fetch_attributes' do
    let(:response) { double(code: 200, success?: true, body: {status: "pending"}) }

    before :each do
      factory
      allow(LittleMonster::API).to receive(:get).and_return(response)
    end

    context 'when requests are disabled' do
      before :each do
        allow(LittleMonster).to receive(:disable_requests?).and_return(true)
      end

      it 'does not make a request' do
        factory.fetch_attributes
        expect(LittleMonster::API).not_to have_received(:get)
      end

      it { expect(factory.fetch_attributes).to eq({}) }
    end

    context 'when requests are enabled' do
      before :each do
        allow(LittleMonster).to receive(:disable_requests?).and_return(false)
      end

      it 'makes a request to api' do
        factory.fetch_attributes
        expect(LittleMonster::API).to have_received(:get)
          .with("/jobs/#{message[:id]}", {}, retries: LittleMonster.job_requests_retries,
                                            retry_wait: LittleMonster.job_requests_retry_wait,
                                            critical: true).once
      end

      it 'fails if job not found' do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(404)
        expect { factory.fetch_attributes }.to raise_error(LittleMonster::JobNotFoundError)
        expect(LittleMonster::API).to have_received(:get)
          .with("/jobs/#{message[:id]}", {}, retries: LittleMonster.job_requests_retries,
                                            retry_wait: LittleMonster.job_requests_retry_wait,
                                            critical: true).once
      end

      it 'fails if request was not successful' do
        # there are cases where typhoeus returns status 200 but success is false
        # normally this is due to a timeout
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(200)
        expect { factory.fetch_attributes }.to raise_error(LittleMonster::APIUnreachableError)
        expect(LittleMonster::API).to have_received(:get)
          .with("/jobs/#{message[:id]}", {}, retries: LittleMonster.job_requests_retries,
                                            retry_wait: LittleMonster.job_requests_retry_wait,
                                            critical: true).once
      end

      context 'when request succeeds' do
        it 'returns request body' do
          expect(factory.fetch_attributes).to eq(response.body)
        end
      end

      context 'when body is emtpy' do
        before :each do
          allow(response).to receive(:success?).and_return(true)
          allow(response).to receive(:body).and_return(nil)
        end

        it 'fails' do
          expect{ factory.fetch_attributes }.to raise_error(LittleMonster::AttributesNotFoundError, "empty api attributes")
        end
      end

      context 'when status is emtpy' do
        before :each do
          allow(response).to receive(:success?).and_return(true)
          allow(response).to receive(:body).and_return({})
        end

        it 'fails' do
          expect{ factory.fetch_attributes }.to raise_error(LittleMonster::AttributesNotFoundError, "empty api attributes")
        end
      end
    end
  end

  describe '#notify_job_task_list' do
    let(:response) { double(success?: true) }

    before :each do
      allow(LittleMonster::API).to receive(:post).and_return(response)
    end

    before :each do
      factory
    end

    context 'when api_attributes tasks is not blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', tasks: [:a, :b, :c]
      end

      it 'returns true' do
        expect(factory.notify_job_task_list).to be true
      end

      it 'does not send any request' do
        factory.notify_job_task_list
        expect(LittleMonster::API).not_to have_received(:post)
      end
    end

    context 'when api_attributes tasks is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', {}
      end

      it 'makes a request to api with job_class task_list, critical, retries and retry wait' do
        mockjob_tasks_name_with_order = [{ name: :task_a, order: 0 }, { name: :task_b, order: 1 }, { name: :task_c, order: 2}]
        factory.notify_job_task_list
        expect(LittleMonster::API).to have_received(:post).with("/jobs/#{message[:id]}/tasks",
                                                                { body: { tasks: mockjob_tasks_name_with_order } },
                                                                retries: LittleMonster.job_requests_retries,
                                                                retry_wait: LittleMonster.job_requests_retry_wait,
                                                                critical: true).once
      end

      it 'returns request success?' do
        expect(factory.notify_job_task_list).to eq(response.success?)
      end
    end

    context 'when notification returns 400' do
      it 'does not fail' do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(400)
        expect(factory.notify_job_task_list).to be true
      end
    end

    context 'when job does not exist' do
      it 'fails' do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(404)
        expect{factory.notify_job_task_list}.to raise_error(LittleMonster::JobNotFoundError)
      end
    end

    context 'when notification is not sucessfull' do
      it 'fails' do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(409)
        expect{factory.notify_job_task_list}.to raise_error(LittleMonster::APIUnreachableError)
      end
    end
  end

  describe '#notify_job_max_retries' do
    let(:response) { double(success?: true) }

    before :each do
      allow(LittleMonster::API).to receive(:put).and_return(response)
    end

    before :each do
      factory
    end

    context 'when api_attributes max_retries is not blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', max_retries: 3
      end

      it 'returns true' do
        expect(factory.notify_job_max_retries).to be true
      end

      it 'does not send any request' do
        factory.notify_job_max_retries
        expect(LittleMonster::API).not_to have_received(:put)
      end
    end

    context 'when api_attributes max_retries is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', {}
      end

      it 'makes a request to api with job_class max_retries' do
        factory.notify_job_max_retries
        expect(LittleMonster::API).to have_received(:put).with("/jobs/#{message[:id]}",
                                                               {
                                                                 body: {
                                                                   max_retries: MockJob.max_retries,
                                                                   callback_retries: MockJob.callback_max_retries
                                                                 }
                                                                },
                                                                retries: LittleMonster.job_requests_retries,
                                                                retry_wait: LittleMonster.job_requests_retry_wait).once
      end

      it 'returns request success?' do
        expect(factory.notify_job_max_retries).to eq(response.success?)
      end
    end
  end

  describe 'find_current_action_and_retries' do
    context 'if api_attributes tasks is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', tasks: []
      end

      it 'returns first tasks of job with 0 retries' do
        expect(factory.find_current_action_and_retries).to eq([:task_a, 0])
      end
    end

    context 'if api_attributes tasks is not blank' do
      let(:api_attributes) do
        {
          tasks: [
            {
              name: 'a',
              retries: 0,
              order: 0,
              status: 'success'
            },{
              name: 'c',
              retries: 1,
              order: 2,
              status: 'pending'
            },{
              name: 'b',
              retries: 1,
              order: 1,
              status: 'running'
            }
          ]
        }
      end

      before :each do
        factory.instance_variable_set '@api_attributes', api_attributes
      end

      context 'if callbacks is blank' do
        it 'returns the first task with not ending status' do
          expect(factory.find_current_action_and_retries).to eq([:b, 1])
        end

        context 'and all tasks have run' do
          before :each do
            api_attributes[:tasks].each { |t| t[:status] = 'success' }
          end

          it 'returns nil' do
            expect(factory.find_current_action_and_retries).to eq(nil)
          end
        end
      end

      context 'if callbacks is not blank' do
        let(:callbacks) do
          [
            {
              name: 'callback2',
              retries: 0,
              status: 'error'
            },{
              name: 'callback',
              retries: 2,
              status: 'pending'
            }
          ]
        end

        before :each do
          api_attributes[:callbacks] = callbacks
        end

        it 'returns the first callback with not ending status' do
          expect(factory.find_current_action_and_retries).to eq([:callback, 2])
        end

        context 'and have ended' do
          before :each do
            api_attributes[:callbacks].each { |c| c[:status] = 'success' }
          end

          it 'returns nil' do
            expect(factory.find_current_action_and_retries).to eq(nil)
          end
        end
      end
    end
  end

  describe '#calculate_status_and_error' do
    context 'if api_attributes tasks is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', tasks: []
      end

      it 'returns pending and empty hash' do
        expect(factory.calculate_status_and_error).to eq([:pending, {}])
      end
    end

    context 'if api_attributes tasks is not blank' do
      let(:api_attributes) do
        {
          tasks: [
            {
              order: 0,
              status: 'success',
              exception: {
                message: 'exception 0'
              }
            },{
              order: 2,
              status: 'pending',
              exception: {
                message: 'exception 2'
              }
            },{
              order: 1,
              status: 'error',
              exception: {
                message: 'exception 1'
              }
            }
          ]
        }
      end

      before :each do
        factory.instance_variable_set '@api_attributes', api_attributes
      end

      context 'on ordered task list' do
        it 'returns the first status that is not success with its exception hash' do
          expect(factory.calculate_status_and_error).to eq([:error, { message: 'exception 1' }])
        end

        context 'if a task is cancelled' do
          before :each do
            api_attributes[:tasks].first[:status] = 'cancelled'
          end

          context 'and no callback has run' do
            it 'returns cancelled' do
              expect(factory.calculate_status_and_error).to eq([:cancelled, { message: 'exception 0' }])
            end
          end

          context 'and on_cancel is pending' do
            before :each do
              api_attributes[:callbacks] = [{ name: 'on_cancel', status: :pending }]
            end

            it 'returns cancelled' do
              expect(factory.calculate_status_and_error).to eq([:cancelled, { message: 'exception 0' }])
            end
          end

          context 'and on_cancel has failed' do
            before :each do
              api_attributes[:callbacks] = [{ name: 'on_cancel', status: :error, exception: { message: 'message' } }]
            end

            it 'returns error' do
              expect(factory.calculate_status_and_error).to eq([:error, { message: 'message' }])
            end
          end
        end

        context 'if all tasks are success' do
          before :each do
            api_attributes[:tasks].each { |t| t[:status] = :success }
          end

          context 'and there are no callbacks' do
            before :each do
              api_attributes[:callbacks] = []
            end

            it 'returns success' do
              expect(factory.calculate_status_and_error).to eq([:success, {}])
            end
          end

          context 'and there are callbacks' do
            it 'returns error if there is a callback on error' do
              api_attributes[:callbacks] = [{ status: :success }, { status: :error, exception: { message: 'message' }}]
              expect(factory.calculate_status_and_error).to eq([:error, { message: 'message' }])
            end

            it 'return success if there is no callback on error' do
              api_attributes[:callbacks] = [{ status: :success }, { status: :success }]
              expect(factory.calculate_status_and_error).to eq([:success, {}])
            end
          end
        end
      end
    end
  end

  describe '#job_attributes' do
    context 'when requests are disabled' do
      it 'returns hash with id tags and input data' do
        expect(factory.job_attributes).to eq(id: message[:id],
                                             data: message[:data],
                                             tags: factory.instance_variable_get('@tags'),
                                             worker_id: worker_id)
      end
    end

    context 'when requests are enabled' do
      let(:data) { { a: 'b' } }
      let(:status) { :status }
      let(:error) { { message: 'message', type: 'type', retry: 1 } }
      let(:retries) { :retries }
      let(:current_action) { :current_action }

      before :each do
        factory.instance_variable_set('@api_attributes', data: data)
        allow(LittleMonster).to receive(:disable_requests?).and_return(false)
        allow(factory).to receive(:calculate_status_and_error).and_return([status, error])
        allow(factory).to receive(:find_current_action_and_retries).and_return([current_action, retries])
      end

      it 'returns hash with id, params, tags, data, calculated_status, current_action and retries' do
        expect(factory.job_attributes).to eq(id: message[:id],
                                             tags: factory.instance_variable_get('@tags'),
                                             worker_id: worker_id,
                                             data: data,
                                             status: status,
                                             error: error,
                                             current_action: current_action,
                                             retries: retries)
      end
    end
  end

  describe '#discard?' do
    context 'if @api_attributes is nil' do
      it 'returns true' do
        factory.instance_variable_set '@api_attributes', nil
        expect(factory.discard?).to be true
      end
    end

    context 'if @api_attributes is not nil' do
      it 'returns true if status is included in ENDED_STATUS' do
        factory.instance_variable_set '@api_attributes', { status: 'error' }
        expect(factory.discard?).to be true
      end

      it 'returns false if status is not included in ENDED_STATUS' do
        factory.instance_variable_set '@api_attributes', { status: 'pending' }
        expect(factory.discard?).to be false
      end
    end
  end
end
