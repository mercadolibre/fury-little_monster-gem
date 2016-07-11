require 'spec_helper'

describe LittleMonster::Core::API do
  subject { described_class }

  let(:path) { '/path' }
  let(:params) { {} }
  let(:options) { { critical: false } }
  let(:response) { double(code: 200, effective_url: '') }

  describe '::get' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end

    context 'given a path params hash and options hash' do
      it 'calls request with get path and params' do
        subject.get path, params, options
        expect(subject).to have_received(:request).with(:get, path, params, options)
      end

      it 'returns the request response' do
        ret = subject.get path, params, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::post' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end


    context 'given a path params hash and options hash' do

      it 'calls request with post path and params' do
        subject.post path, params, options
        expect(subject).to have_received(:request).with(:post, path, params, options)
      end

      it 'returns the request response' do
        ret = subject.post path, params, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::put' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end


    context 'given a path params hash and options hash' do

      it 'calls request with put path and params' do
        subject.put path, params, options
        expect(subject).to have_received(:request).with(:put, path, params, options)
      end

      it 'returns the request response' do
        ret = subject.put path, params, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::patch' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end


    context 'given a path params hash and options hash' do

      it 'calls request with patch path and params' do
        subject.patch path, params, options
        expect(subject).to have_received(:request).with(:patch, path, params, options)
      end

      it 'returns the request response' do
        ret = subject.patch path, params, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::delete' do
    before :each do
      allow(subject).to receive(:request).and_return(response)
    end


    context 'given a path params hash and options hash' do

      it 'calls request with delete path and params' do
        subject.delete path, params, options
        expect(subject).to have_received(:request).with(:delete, path, params, options)
      end

      it 'returns the request response' do
        ret = subject.delete path, params, options
        expect(ret).to eq(response)
      end
    end
  end

  describe '::request' do
    let(:method) { :get }
    let(:url) { "http://little_monster_api_url.com#{path}" }

    before :each do
      allow(Typhoeus).to receive(method).and_return(response)
      allow(subject).to receive(:sleep)
    end

    context 'given method, path params and options' do
      it 'calls typhoeus with method url and params' do
        subject.request method, path, params, options
        expect(Typhoeus).to have_received(method)
          .with(url, params)
      end

      context 'request built' do
        it 'has body dumped to json' do
          body = { a: :b }
          params[:body] = body
          subject.request method, path, params, options
          expect(Typhoeus).to have_received(method)
            .with(url, hash_including(body: MultiJson.dump(body)))
        end

        it 'has tiemout set to configured timeout' do
          subject.request method, path, params, options
          expect(Typhoeus).to have_received(method)
            .with(url, hash_including(timeout: LittleMonster.request_timeout))
        end

        it 'has content type set to json if it was not specified' do
          subject.request method, path, params, options
          expect(Typhoeus).to have_received(method)
            .with(url, hash_including(headers: { 'Content-Type' => 'application/json' }))
        end

        it 'has content type set to json if specified' do
          headers = { 'Content-Type' => 'something' }
          params[:headers] = headers
          subject.request method, path, params, options
          expect(Typhoeus).to have_received(method)
            .with(url, hash_including(headers: headers))
        end
      end

      it 'returns the response' do
        expect(subject.request method, path, params).to eq(response)
      end

      context 'returned response' do
        it 'has json body parsed to hash if it is json' do
          allow(response).to receive(:params).and_return(response_body: '{}')
          expect(subject.request(method, path, params).body.class).to be Hash
        end

        it 'has raw body if it is not json' do
          allow(response).to receive(:params).and_return(response_body: 'something')
          expect(subject.request(method, path, params).body.class).to be String
        end
      end

      context 'if status < 500'  do
        it 'makes only one request' do
          subject.request method, path, params, options
          expect(Typhoeus).to have_received(method).once
        end
      end

      context 'if status >= 500' do
        before :each do
          allow(response).to receive(:code).and_return(500)
        end

        context 'if no retry configs were passed' do
          it 'waits the default amount of time between requests' do
            subject.request method, path, params, options
            expect(subject).to have_received(:sleep).with(LittleMonster.default_request_retry_wait)
              .exactly(LittleMonster.default_request_retries).times
          end

          it 'retries the defaulted amount of times' do
            subject.request method, path, params, options
            expect(Typhoeus).to have_received(method)
              .exactly(LittleMonster.default_request_retries+1).times #es la cantidad de retries +1 de el primer request
          end
        end

        context 'given retries and retry_wait in options' do
          let(:retries) { LittleMonster.default_request_retries+1 }
          let(:retry_wait) { LittleMonster.default_request_retry_wait+1 }

          before :each do
            options[:retries] = retries
            options[:retry_wait] = retry_wait
          end

          it 'waits the specified amount of time between requests' do
            subject.request method, path, params, options
            expect(subject).to have_received(:sleep).with(retry_wait)
              .exactly(retries).times
          end

          it 'retries the specified amount of times' do
            subject.request method, path, params, options
            expect(Typhoeus).to have_received(method)
              .exactly(retries+1).times
          end
        end

        context 'if request is critical' do
          it 'raises APIUnreachableError after all requests fail' do
            params[:critical] = true
            expect { subject.request method, path, params }.to raise_error(LittleMonster::APIUnreachableError, "critical request to #{path} has fail, check little monster api")
          end
        end
      end
    end
  end
end
