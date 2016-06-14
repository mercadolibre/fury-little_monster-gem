require 'spec_helper'

describe LittleMonster::Core::API do
  subject { described_class }

  let(:path) { '/path' }
  let(:options) { {} }
  let(:response) { double(code: 200, effective_url: '') }

  describe '::get' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path and an options hash' do
      it 'calls request with get path and options' do
        subject.get path, options
        expect(subject).to have_received(:request).with(:get, path, options)
      end

      it 'returns the request response' do
        ret = subject.get path, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::post' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path and an options hash' do
      it 'calls request with post path and options' do
        subject.post path, options
        expect(subject).to have_received(:request).with(:post, path, options)
      end

      it 'returns the request response' do
        ret = subject.post path, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::put' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path and an options hash' do
      it 'calls request with put path and options' do
        subject.put path, options
        expect(subject).to have_received(:request).with(:put, path, options)
      end

      it 'returns the request response' do
        ret = subject.put path, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::patch' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path and an options hash' do
      it 'calls request with patch path and options' do
        subject.patch path, options
        expect(subject).to have_received(:request).with(:patch, path, options)
      end

      it 'returns the request response' do
        ret = subject.patch path, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::delete' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path and an options hash' do
      it 'calls request with delete path and options' do
        subject.delete path, options
        expect(subject).to have_received(:request).with(:delete, path, options)
      end

      it 'returns the request response' do
        ret = subject.delete path, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::request' do
    let(:method) { :get }

    before :each do
      allow(Typhoeus).to receive(method).and_return(response)
    end

    context 'given method, path and options' do
      it 'calls typhoeus with method url and options' do
        url = "http://little_monster_api_url.com#{path}"
        subject.request method, path, options
        expect(Typhoeus).to have_received(method)
          .with(url, options)
      end

      it 'returns the response' do
        expect(subject.request method, path, options).to eq(response)
      end

      context 'if status < 500'  do
        it 'makes only one request' do
          subject.request method, path, options
          expect(Typhoeus).to have_received(method).once
        end
      end

      context 'if status >= 500' do
        before :each do
          allow(response).to receive(:code).and_return(500)
        end

        it 'retries the amount of times configured' do
          subject.request method, path, options
          expect(Typhoeus).to have_received(method)
            .exactly(LittleMonster.api_request_retries).times
        end
      end
    end
  end
end
