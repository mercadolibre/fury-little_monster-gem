require 'spec_helper'

describe LittleMonster::Core::Job::Factory do
  let(:message) do
    {
      id: 0,
      name: :mock_job,
      data: { a: :b },
      tags: { c: :d }
    }
  end

  let(:factory) { described_class.new message }

  describe '#initialize' do
    it { expect(factory.instance_variable_get '@id').to eq(message[:id]) }
    it { expect(factory.instance_variable_get '@name').to eq(message[:name]) }
    it { expect(factory.instance_variable_get '@input_data').to eq(message[:data]) }
    it { expect(factory.instance_variable_get '@tags').to eq(message[:tags]) }

    it 'fetches attributes from api' do
      allow_any_instance_of(described_class).to receive(:fetch_attributes).and_call_original
      expect(factory).to have_received(:fetch_attributes).once
    end
  end

  describe '#build' do
    it 'returns if should_build? is false' do
      allow(factory).to receive(:should_build?).and_return(false)
      expect(factory.build).to be_nil
    end

    it 'builds job class out of name if should_build? is true' do
      allow(factory).to receive(:should_build?).and_return(true)
      allow(MockJob).to receive(:new).and_call_original
      factory.build
      expect(MockJob).to have_received(:new)
        .with(factory.job_attributes)
    end
  end

  describe '#fetch_attributes' do
    let(:response) { double(success?: true, body: double) }

    before :each do
      allow(LittleMonster::API).to receive(:get).and_return(response)
    end

    context 'when env is test or development' do
      before :each do
        allow(LittleMonster).to receive(:env).and_return('test')
      end

      it 'does not make a request' do
        factory.fetch_attributes
        expect(LittleMonster::API).not_to have_received(:get)
      end

      it { expect(factory.fetch_attributes).to eq({}) }
    end

    context 'when env is not test nor development' do
      before :each do
        factory #call factory to initialize it
        allow(LittleMonster).to receive(:env).and_return('production')
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

  describe '#find_current_task' do
    let(:api_attributes) do
      {
        tasks: [
          {
            name: 'a',
            retries: 0,
            status: 'finished'
          },{
            name: 'b',
            retries: 1,
            status: 'pending'
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

    it 'returns the first task with status pending from api attributes with symbolized name' do
      expect(factory.find_current_task[:name]).to eq(:b)
    end

    it 'returns empty hash if no task is pending' do
      api_attributes[:tasks].last[:status] = 'finished'
      expect(factory.find_current_task).to eq({})
    end
  end

  describe '#job_attributes' do
    context 'when env is development or test' do
      it 'returns hash with id tags and input data' do
        expect(factory.job_attributes).to eq(id: message[:id],
                                             data: message[:data],
                                             tags: message[:tags])
      end
    end

    context 'when env is not development or test' do
      let(:current_task) { { name: 'name', retries: 0 } }
      let(:data) { {} }

      before :each do
        allow(factory).to receive(:find_current_task).and_return(current_task)
        factory.instance_variable_set('@api_attributes', data: data)
        allow(LittleMonster).to receive(:env).and_return('production')
      end

      it 'returns hash with id params tags data current_task and retries' do
        expect(factory.job_attributes).to eq(id: message[:id],
                                             tags: message[:tags],
                                             data: data,
                                             current_task: current_task[:name],
                                             retries: current_task[:retries])
      end
    end
  end

  describe '#should_build?' do
    context 'if @api_attributes is nil' do
      before :each do
        factory.instance_variable_set '@api_attributes', nil
      end

      it 'returns false' do
        expect(factory.should_build?).to be false
      end
    end

    context 'if @api_attributes is not nil' do
      it 'returns true if api_attributes[status] is pending' do
        factory.instance_variable_set '@api_attributes', { status: 'pending' }
        expect(factory.should_build?).to be true
      end

      it 'returns false if api_attributes[status] is not pending' do
        factory.instance_variable_set '@api_attributes', { status: 'running' }
        expect(factory.should_build?).to be false
      end
    end
  end
end
