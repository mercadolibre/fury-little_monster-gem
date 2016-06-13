require 'spec_helper'

describe LittleMonster::RSpec do
  describe 'load' do
    let(:rspec_conf) do
      instance_double RSpec::Core::Configuration
    end

    before :each do
      allow(rspec_conf).to receive(:include)
      allow(RSpec).to receive(:configure).and_yield(rspec_conf)

      load './lib/little_monster/rspec.rb'
    end

    it 'includes job_helper in rspec' do
      expect(rspec_conf).to have_received(:include).with(LittleMonster::RSpec::JobHelper)
    end

    it 'includes task_helper in rspec' do
      expect(rspec_conf).to have_received(:include).with(LittleMonster::RSpec::TaskHelper)
    end

    it 'includes matchers module in rspec' do
      expect(rspec_conf).to have_received(:include).with(LittleMonster::RSpec::Matchers)
    end
  end
end
