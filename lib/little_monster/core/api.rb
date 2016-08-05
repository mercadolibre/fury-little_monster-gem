require 'typhoeus'
require 'multi_json'

module LittleMonster::Core
  class API
    extend Loggable

    class << self
      def get(path, params = {}, options = {})
        request :get, path, params, options
      end

      def post(path, params = {}, options = {})
        request :post, path, params, options
      end

      def put(path, params = {}, options = {})
        request :put, path, params, options
      end

      def patch(path, params = {}, options = {})
        request :patch, path, params, options
      end

      def delete(path, params = {}, options = {})
        request :delete, path, params, options
      end

      def request(method, path, params = {}, retries: LittleMonster.default_request_retries,
                  retry_wait: LittleMonster.default_request_retry_wait,
                  critical: false)
        ret = 0
        res = nil
        url = [LittleMonster.api_url.chomp('/'), path.sub(/\//, '')].join '/'

        params[:body] = MultiJson.dump params.fetch(:body, {}) unless params[:body].is_a? String
        params[:headers] ||= {}
        params[:headers]['Content-Type'] = 'application/json' unless params[:headers]['Content-Type']
        params[:timeout] = LittleMonster.request_timeout

        begin
          res = Typhoeus.public_send method, url, params
          raise FuryHttpApiError, "request to #{res.effective_url} failed with status #{res.code} retry #{ret}" if res.code >= 500 || res.code.zero?
        rescue StandardError => e
          logger.error e.message
          if ret < retries
            sleep(retry_wait)
            ret += 1
            retry
          end

          logger.error "[type:request_max_retries_reached][url:#{url}][retries:#{ret}] request has reached max retries"

          if critical
            logger.error "[type:critical_request_failed][url:#{url}][retries:#{ret}] request has reached max retries"
            raise APIUnreachableError, "critical request to #{url} has fail, check little monster api"
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
    class FuryHttpApiError < StandardError; end
  end
end
