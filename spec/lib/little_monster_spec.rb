require 'spec_helper'

describe LittleMonster do
  it 'includes the core module' do
    expect(LittleMonster).to include(LittleMonster::Core)
  end

  specify 'default values' do
    LittleMonster.default_config_values == {
      little_monster_api_url: 'http://little_monster_api_url.com/',
      api_request_retries: 4
    }
  end

  describe 'module functions' do
    describe '::init' do
      let(:config) { instance_double LittleMonster::Config }

      before :each do
        allow(LittleMonster::Config).to receive(:new).and_return(config)
        LittleMonster.init
      end

      it 'sets config static variable' do
        expect(LittleMonster.class_variable_get('@@config')).to eq(config)
      end

      it 'builds new config with default value' do
        expect(LittleMonster::Config).to have_received(:new).with(LittleMonster.default_config_values)
      end
    end

    describe '::configure' do
      let(:config) { instance_double LittleMonster::Config }

      before :each do
        LittleMonster.class_variable_set '@@config', config
      end

      it 'yields the config from the module' do
        expect { |b| LittleMonster.configure(&b) }.to yield_with_args(config)
      end
    end

    describe '::method_missing' do
      let(:config) { double }

      before :each do
        LittleMonster.class_variable_set '@@config', config
        allow(config).to receive(:mock_method).and_return(1)
      end

      context 'if config responds to that method' do
        it 'returns the value from config' do
          expect(LittleMonster.mock_method).to eq(config.mock_method)
        end
      end

      context 'if config does not respond to that method' do
        it 'raises no method error' do
          expect { LittleMonster.not_existing_method }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
