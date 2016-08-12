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

  let(:factory) { described_class.new message }

  describe '#initialize' do
    it { expect(factory.instance_variable_get '@id').to eq(message[:id]) }
    it { expect(factory.instance_variable_get '@name').to eq(message[:name]) }
    it { expect(factory.instance_variable_get '@input_data').to eq(message[:data]) }
    it { expect(factory.instance_variable_get '@job_class').to eq(MockJob) }

    it 'fetches attributes from api' do
      allow_any_instance_of(described_class).to receive(:fetch_attributes).and_call_original
      expect(factory).to have_received(:fetch_attributes).once
    end

    it 'raises JobNotFoundError if job class does not exists' do
      message[:name] = 'not_existing_class'
      allow(LittleMonster::API).to receive(:put)
      expect { factory }.to raise_error(LittleMonster::JobNotFoundError)
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
    let(:response) { double(success?: true, body: double) }

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

      context 'when request succeds' do
        it 'returns request body' do
          expect(factory.fetch_attributes).to eq(response.body)
        end
      end

      context 'when request fails' do
        before :each do
          allow(response).to receive(:success?).and_return(false)
        end

        it { expect(factory.fetch_attributes).to be_nil }
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
        mockjob_tasks_name_with_order = [{ name: :task_a, order: 0 }, { name: :task_b, order: 1 }]
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
                                                               { body: { max_retries: MockJob.max_retries } },
                                                                retries: LittleMonster.job_requests_retries,
                                                                retry_wait: LittleMonster.job_requests_retry_wait).once
      end

      it 'returns request success?' do
        expect(factory.notify_job_max_retries).to eq(response.success?)
      end
    end
  end

  describe '#find_current_task' do
    context 'if api_attributes is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', tasks: []
      end

      it 'returns a hash with first task and retry at 0' do
        expect(factory.find_current_task).to eq(name: MockJob.tasks.first, retries: 0)
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

      it 'returns a hash with name retries' do
        expect(factory.find_current_task.keys).to eq([:name, :retries])
      end

      it 'returns the first task with not ending status from sorted api attributes with symbolized name' do
        expect(factory.find_current_task[:name]).to eq(:b)
      end

      it 'returns empty hash if all tasks ended' do
        api_attributes[:tasks].each { |t| t[:status] = 'success' }
        expect(factory.find_current_task).to eq({})
      end
    end
  end

  describe '#calculate_status' do
    context 'if api_attributes tasks is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', tasks: []
      end

      it 'returns pending' do
        expect(factory.calculate_status).to eq(:pending)
      end
    end

    context 'if api_attributes tasks is not blank' do
      let(:api_attributes) do
        {
          tasks: [
            {
              order: 0,
              status: 'success'
            },{
              order: 2,
              status: 'pending'
            },{
              order: 1,
              status: 'error'
            }
          ]
        }
      end

      before :each do
        factory.instance_variable_set '@api_attributes', api_attributes
      end

      context 'on ordered task list' do
        it 'returns the first status that is not success' do
          expect(factory.calculate_status).to eq(:error)
        end

        context 'if all tasks are success' do
          before :each do
            api_attributes[:tasks].each { |t| t[:status] = :success }
          end

          it 'returns success' do
            expect(factory.calculate_status).to eq(:success)
          end
        end
      end
    end
  end

  describe '#retries_from_callback' do
    context 'if api_attributes[callbacks] is blank' do
      before :each do
        factory.instance_variable_set '@api_attributes', callbacks: []
      end

      it 'returns 0' do
        expect(factory.retries_from_callback).to eq(0)
      end
    end

    context 'if api_attributes[callbacks] is not blank' do
      let(:api_attributes) do
        {
          callbacks: [
            {
              name: 'on_success',
              status: 'error',
              retries: 3
            },{
              name: 'on_error',
              status: 'pending',
              retries: 1
            }
          ]
        }
      end

      before :each do
        factory.instance_variable_set '@api_attributes', api_attributes
      end

      it 'returns the amount of retries made by the first callback with a not ended status' do
        expect(factory.retries_from_callback).to eq(1)
      end
    end
  end

  describe '#job_attributes' do
    context 'when requests are disabled' do
      it 'returns hash with id tags and input data' do
        expect(factory.job_attributes).to eq(id: message[:id],
                                             data: message[:data],
                                             tags: factory.instance_variable_get('@tags'))
      end
    end

    context 'when requests are enabled' do
      let(:data) { { a: 'b' } }

      before :each do
        factory.instance_variable_set('@api_attributes', data: data)
        allow(LittleMonster).to receive(:disable_requests?).and_return(false)
      end

      context 'if calculated_status is an ended_status' do
        let(:status) { :error }
        let(:retries_from_callback) { 5 }

        before :each do
          allow(factory).to receive(:retries_from_callback).and_return(retries_from_callback)
          allow(factory).to receive(:calculate_status).and_return(status)
        end

        it 'returns hash with id params tags data, status current_task as nil and retries from callback' do
          expect(factory.job_attributes).to eq(id: message[:id],
                                               tags: factory.instance_variable_get('@tags'),
                                               data: data,
                                               status: status,
                                               current_task: nil,
                                               retries: retries_from_callback)
        end
      end

      context 'if calculated_status is not an ended_status' do
        let(:current_task) { { name: 'name', retries: 0 } }
        let(:status) { :running }

        before :each do
          allow(factory).to receive(:find_current_task).and_return(current_task)
          allow(factory).to receive(:calculate_status).and_return(status)
        end

        it 'returns hash with id params tags data status current_task and retries from current_task' do
          expect(factory.job_attributes).to eq(id: message[:id],
                                               tags: factory.instance_variable_get('@tags'),
                                               data: data,
                                               status: status,
                                               current_task: current_task[:name],
                                               retries: current_task[:retries])
        end
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
