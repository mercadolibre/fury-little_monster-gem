require 'spec_helper'

describe LittleMonster::Core::Job::Factory do
  let(:message) do
    {
      id: 0,
      name: :mock_job,
      params: { a: :b },
      tags: { c: :d }
    }
  end

  let(:factory) { described_class.new message }

  describe '#initialize' do
    it { expect(factory.instance_variable_get '@id').to eq(message[:id]) }
    it { expect(factory.instance_variable_get '@name').to eq(message[:name]) }
    it { expect(factory.instance_variable_get '@params').to eq(message[:params]) }
    it { expect(factory.instance_variable_get '@tags').to eq(message[:tags]) }
  end

  describe '#build' do
    it 'fetches attributes from api' do
      allow(factory).to receive(:fetch_attributes).and_call_original
      factory.build
      expect(factory).to have_received(:fetch_attributes).once
    end

    it 'returns if fetched attributes have status not pending' do
      allow(factory).to receive(:fetch_attributes).and_return(status: 'running')
      expect(factory.build).to be_nil
    end

    it 'builds job class out of name' do
      allow(MockJob).to receive(:new).and_call_original
      factory.build
      expect(MockJob).to have_received(:new)
        .with(id: message[:id], params: message[:params], tags: message[:tags])
    end
  end

  describe '#fetch_attributes' do
    it 'fetches the job attributes from api'
  end

  describe '#find_current_task' do
    let(:api_attributes) do
      {
        tasks: [
          {
            name: 'a',
            retries: 0,
            output: {},
            status: 'finished'
          },{
            name: 'b',
            retries: 1,
            output: {},
            status: 'pending'
          }
        ]
      }
    end

    before :each do
      factory.instance_variable_set '@api_attributes', api_attributes
    end

    it 'returns a hash with name retries and previous_output' do
      expect(factory.find_current_task.keys).to eq([:name, :retries, :previous_output])
    end

    it 'returns the first task with status pending from api attributes' do
      expect(factory.find_current_task[:name]).to eq('b')
    end

    context 'previous_output' do
      context 'when selected tasks is the first' do
        before :each do
          api_attributes[:tasks].first[:status] = 'pending'
          factory.instance_variable_set '@api_attributes', api_attributes
        end

        it 'is nil' do
          expect(factory.find_current_task[:previous_output]).to be_nil
        end
      end

      context 'when selected task is not the first' do
        it 'is the output of the previous task' do
          expect(factory.find_current_task[:previous_output]).to eq({})
        end
      end
    end

  end
end
