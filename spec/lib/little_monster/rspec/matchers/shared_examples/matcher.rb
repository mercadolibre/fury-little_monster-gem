RSpec.shared_examples 'matcher' do |parameter|
	let(:matcher) { described_class }

  let(:matcher_function) { matcher.to_s.underscore.split('/').last }

  context 'matcher module' do
    it 'responds to matcher method' do
      expect(LittleMonster::RSpec::Matchers.method_defined? matcher_function).to be true
    end

    context 'function' do
      let(:params) { double }
      before :each do
        allow(matcher).to receive(:new)
      end

      it 'creates a new matcher object with method params' do
        send(matcher_function, *params)
        expect(matcher).to have_received(:new).with(params)
      end
    end
  end
end
