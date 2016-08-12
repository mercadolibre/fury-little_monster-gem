require 'spec_helper'

describe LittleMonster::Core::JobNotFoundError do
  describe '#initialize' do
    let(:job_id) { 23 }
    let(:error) { LittleMonster::Core::JobNotFoundError }

    before :each do
      allow(LittleMonster::API).to receive(:put)
      error.new(job_id)
    end

    it 'sends status error' do
      expect(LittleMonster::API).to have_received(:put) do |url, params, options|
        expect(params[:body][:status]).to eq('error')
      end
    end

    it 'is a critical request' do
      expect(LittleMonster::API).to have_received(:put) do |url, params, options|
        expect(options[:critical]).to eq(true)
      end
    end

    it 'sends the put to the job_id' do
      expect(LittleMonster::API).to have_received(:put).with("/jobs/#{job_id}", any_args).once
    end
  end
end
