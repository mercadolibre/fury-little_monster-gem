require 'spec_helper'

describe LittleMonster::Core::Counters do
  let(:dummy_class) do
    class DummyClass < LittleMonster::Task
      include LittleMonster::Counters

      def initialize
        @job_id=1
      end
    end
    DummyClass.new
  end

  context '.increase_count' do
    context 'success' do
      def success_mock(status='success', output='')
        expect(LittleMonster::Core::API).to receive(:put)
        .with('/jobs/1/counters/my_counter',{ body: { unique_id: "my_unique_id",type: status, output: output} }, critical:true)
        .and_return(Typhoeus::Response.new(code:200)).once
      end

      it 'Put to LM api' do
        success_mock
        dummy_class.increase_counter('my_counter',"my_unique_id",'success')
      end

      it 'add 1 when succeded' do
        success_mock
        dummy_class.increase_counter('my_counter',"my_unique_id",'success')
      end

      it 'add 1 when status fail' do
        success_mock('fail')
        dummy_class.increase_counter('my_counter',"my_unique_id",'fail')
      end

      it 'allows send output' do
        output="my fake output"
        success_mock('fail',output)
        dummy_class.increase_counter('my_counter',"my_unique_id",'fail', output)
      end
    end

    it 'raise CounterError on duplicate unique_id' do
      ret = Typhoeus::Response.new(code:412)

      expect(LittleMonster::Core::API).to(receive(:put))
      .with('/jobs/1/counters/my_counter',{body: { type: 'fail',unique_id:"my_unique_id",output: ''}}, critical:true)
      .and_return(ret)

      expect { dummy_class.increase_counter('my_counter',"my_unique_id",'fail')}
      .to raise_error LittleMonster::Core::Counters::DuplicatedCounterError
    end


    it 'fails if couldn\'t send counter to the api' do
      expect(LittleMonster::Core::API).to(receive(:put))
      .and_raise(LittleMonster::APIUnreachableError)
      expect { dummy_class.increase_counter('my_counter',"my_unique_id",'fail')}.to raise_error LittleMonster::APIUnreachableError
    end
  end

  context 'counter' do
    let(:response) do
      { "name":"pepe",
        "total":1,
        "failed": {
          "total":0,
          "outputs":[]
        },
        "succeeded":{
          "total":1,
          "outputs":[{
            "unique_id":"fake_unique",
            "output":"fake_output"}]}}
    end

    context :success do
      before :each do
        expect(LittleMonster::Core::API).to receive(:get)
        .with('/jobs/1/counters/my_counter', {}, critical:true)
        .and_return(Typhoeus::Response.new(body:response,code:200))
      end

      it 'has to return counter with total, failed and succeed' do
        expect(dummy_class.counter('my_counter')).to include(:total,:failed,:succeeded)
      end

      it 'succeeded has total and output' do
        expect(dummy_class.counter('my_counter')[:succeeded]).to include(:total,:outputs)
      end

      it 'failed has total and output' do
        expect(dummy_class.counter('my_counter')[:succeeded]).to include(:total,:outputs)
      end
    end

  end

  context '.init_counters' do
    context 'success' do
      def success_mock(status='success', output='')
        allow_any_instance_of(Typhoeus::Response).to receive(:success?).and_return(true)
        expect(LittleMonster::Core::API).to receive(:post)
        .with('/jobs/1/counters/my_counter', critical: true)
        .and_return(Typhoeus::Response.new(code: 200))
      end

      it 'Post to LM api' do
        success_mock
        dummy_class.init_counters('my_counter')
      end

      it 'Post to LM api as many times as counters amount' do
        allow_any_instance_of(Typhoeus::Response).to receive(:success?).and_return(true)
        allow(LittleMonster::Core::API).to receive(:post).and_return(Typhoeus::Response.new(code: 200))
        dummy_class.init_counters('my_counter1', 'my_counter2')
        expect(LittleMonster::Core::API).to have_received(:post).twice
      end
    end

    it 'fails if couldn\'t send counter to the api' do
      allow(LittleMonster::Core::API).to receive(:post).and_raise(LittleMonster::APIUnreachableError)
      expect { dummy_class.init_counters('my_counter1', 'my_counter2') }.to raise_error LittleMonster::APIUnreachableError
    end

    it 'fails if counter does not exists' do
      allow(LittleMonster::Core::API).to receive(:post).and_return(Typhoeus::Response.new(code: 404))
      expect { dummy_class.init_counters('my_counter1', 'my_counter2') }.to raise_error LittleMonster::Core::Counters::MissedCounterError
    end

    it 'does not fails if counter already exists' do
      allow(LittleMonster::Core::API).to receive(:post).and_return(Typhoeus::Response.new(code: 409))
      expect { dummy_class.init_counters('my_counter1', 'my_counter2') }.not_to raise_error
    end
  end

  context '.counter_endpoint' do 
    it 'have to return api endpoint' do 
      expect(dummy_class.counter_endpoint('fake')).to eq 'http://little_monster_api_url.com/jobs/1/counters/fake'
    end
  end
end
