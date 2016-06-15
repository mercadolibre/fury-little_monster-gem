require 'typhoeus'
require 'multi_json'

module LittleMonster::Core
  class API
    include Loggable

    class << self
      def get(path, options={})
        request :get, path, options
      end

      def post(path, options={})
        request :post, path, options
      end

      def put(path, options={})
        request :put, path, options
      end

      def patch(path, options={})
        request :patch, path, options
      end

      def delete(path, options={})
        request :delete, path, options
      end

      def request(method, path, options={})
        retries = 1
        res = nil
        url = [LittleMonster.api_url.chomp('/'), path.sub(/\//, '')].join '/'

        options[:body] = MultiJson.dump options.fetch(:body, {})
        options[:headers] ||= {}
        options[:headers]['Content-Type'] = 'application/json' unless options[:headers]['Content-Type']

        begin
          res = Typhoeus.public_send method, url, options
          raise StandardError, "request to #{res.effective_url} failed with status #{res.code} retry #{retries}" if res.code >= 500
        rescue StandardError => e
          logger.error e.message
          retries += 1
          retry if retries <= LittleMonster.api_request_retries
        end

        res
      end
    end
  end
end
