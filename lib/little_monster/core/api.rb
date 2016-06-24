require 'typhoeus'
require 'multi_json'

module LittleMonster::Core
  class API
    include Loggable

    class << self
      def get(path, options = {})
        request :get, path, options
      end

      def post(path, options = {})
        request :post, path, options
      end

      def put(path, options = {})
        request :put, path, options
      end

      def patch(path, options = {})
        request :patch, path, options
      end

      def delete(path, options = {})
        request :delete, path, options
      end

      def request(method, path, options = {})
        retries = 0
        res = nil
        url = [LittleMonster.api_url.chomp('/'), path.sub(/\//, '')].join '/'

        options[:body] = MultiJson.dump options.fetch(:body, {})
        options[:headers] ||= {}
        options[:headers]['Content-Type'] = 'application/json' unless options[:headers]['Content-Type']

        options[:timeout] = LittleMonster.request_timeout

        begin
          res = Typhoeus.public_send method, url, options
          raise StandardError, "request to #{res.effective_url} failed with status #{res.code} retry #{retries}" if res.code >= 500
        rescue StandardError => e
          logger.error e.message
          if retries < options.fetch(:retries, LittleMonster.default_request_retries)
            sleep(options.fetch(:retry_wait, LittleMonster.default_request_retry_wait))
            retries += 1
            retry
          end
        end

        res.define_singleton_method(:body) do
          begin
            MultiJson.load(res.options[:response_body], symbolize_keys: true)
          rescue
            res.options[:response_body]
          end
        end

        res
      end
    end
  end
end
