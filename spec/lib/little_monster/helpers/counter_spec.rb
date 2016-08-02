require_relative '../../../../lib/little_monster/helpers/counters'
describe LittleMonster::Counters do 
  let(:dummy_class) do 
    Class.new do 
      include LittleMonster::Counters
      def initialize
        @job_id=1
      end
    end.new
  end

  context '.increase_count' do
    context 'success' do 
      def success_mock(status='success', output='')
        expect(LittleMonster::Core::API).to receive(:put)
        .with('/jobs/1/counters/my_counter',{ type: status, output: output})
        .and_return(Typhoeus::Response.new(code:200)).once
      end

      it 'Put to LM api' do
        success_mock
        dummy_class.increase_counter('my_counter','success')
      end

      it 'add 1 when succeded' do
        success_mock
        dummy_class.increase_counter('my_counter','success')
        #resp = 
      end
      
      it 'add 1 when status fail' do 
        success_mock('fail')
        dummy_class.increase_counter('my_counter','fail')
      end

      it 'allows send output' do 
        output="my fake output"
        success_mock('fail',output)
        dummy_class.increase_counter('my_counter','fail', output)
      end
    end

    it 'raise CounterError on duplicate unique_id' do
      ret = Typhoeus::Response.new(code:412)
      
      expect(LittleMonster::Core::API).to(receive(:put))
      .with('/jobs/1/counters/my_counter',{ type: 'fail',output: ''})
      .and_return(ret)

      expect { dummy_class.increase_counter('my_counter','fail')}
      .to raise_error LittleMonster::Counters::DuplicatedCounterError
    end


    it 'fails if couldn\'t send counter to the api' do 
      expect(LittleMonster::Core::API).to(receive(:put))
      .and_raise(LittleMonster::Core::API::FuryHttpApiError)
      expect { dummy_class.increase_counter('my_counter','fail')}.to raise_error LittleMonster::Counters::ApiError
    end
  end
end
