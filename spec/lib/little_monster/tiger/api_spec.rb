require 'spec_helper'

describe LittleMonster::Tiger::API do
  subject(:api) { described_class }

  before do
    LittleMonster::Tiger::Cache.instance.cache.clear
    allow(File).to receive(:read).with(LittleMonster.shark_login_file_path).and_return('')
  end

  describe '.bearer_token' do
    context 'when the shark login success' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { JSON.parse(body_str) }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
      end

      it 'return correct bearer token' do
        expect(api.bearer_token).to eq("Bearer #{body['token']}")
      end
    end

    context 'when the shark login fail' do
      before do
        LoginSharkMock.new(self).login_request_failure
      end

      it 'return nil' do
        expect(api.bearer_token).to be_nil
      end
    end
  end

  describe '.cached_shark_token' do
    context 'when the shark login success' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { JSON.parse(body_str) }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
      end

      it 'return correct token' do
        expect(api.cached_shark_token).to eq(body['token'])
      end
    end

    context 'when the shark login fail' do
      before do
        LoginSharkMock.new(self).login_request_failure
      end

      it 'return nil' do
        expect(api.cached_shark_token).to be_nil
      end
    end

    context 'when called cached_shark_token the next call' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { JSON.parse(body_str) }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
        api.cached_shark_token
        allow(Typhoeus::Request).to receive(:new).and_call_original
      end

      it 'dont request to login endpoint' do

        api.cached_shark_token
        expect(Typhoeus::Request).not_to have_received(:new)
      end
    end

    context 'when called cached_shark_token for first time' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { JSON.parse(body_str) }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
        allow(Typhoeus::Request).to receive(:new).and_call_original
      end

      it 'request to login endpoint' do
        api.cached_shark_token
        expect(Typhoeus::Request).to have_received(:new)
      end
    end
  end

  describe '.new_shark_token' do
    context 'when the shark login success' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { JSON.parse(body_str) }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
      end

      it 'return correct token' do
        expect(api.new_shark_token).to eq(body['token'])
      end
    end

    context 'when the shark login fail' do
      before do
        LoginSharkMock.new(self).login_request_failure
      end

      it 'return nil' do
        expect(api.new_shark_token).to be_nil
      end
    end
  end

  describe '.make_call' do
    let(:method) { :post }
    let(:endpoint) { 'login/shark' }
    let(:options) { { body: body } }
    let(:body) { { token: '' }.to_json }

    context 'when the shark login success' do
      let(:body_str) { File.open('./spec/mock/responses/tiger_token.json', 'r').read }
      let(:body) { { token: '' }.to_json }

      before do
        LoginSharkMock.new(self).login_request_success(body_str)
      end

      it 'return success request' do
        expect(api.make_call(method, endpoint, options)).to be_success
      end
    end

    context 'when the shark login fail' do
      before do
        LoginSharkMock.new(self).login_request_failure
      end

      it 'return correct bearer token' do
        expect(api.make_call(method, endpoint, options)).to be_failure
      end
    end
  end
end
