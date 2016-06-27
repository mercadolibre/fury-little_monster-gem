require 'spec_helper'

describe LittleMonster::Config do
  describe 'initalize' do
    context 'given a hash of params' do
      let(:params) do
        {
          little_monster_api_url: 'little_monster_api_url',
          api_request_retries: 100,
          worker_concurrency: 200,
          worker_queue: nil,
          key: :value
        }
      end

      let(:config) { LittleMonster::Config.new params }

      it 'sets an instance variable for each element of the hash' do
        params.each do |key, value|
          expect(config.instance_variable_get("@#{key}")).to eq(value)
        end
      end
    end
  end
end
