require 'typhoeus'
require 'multi_json'
require 'securerandom'

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

        request_id = SecureRandom.uuid
        ret = 0
        res = nil
        url = [LittleMonster.api_url.chomp('/'), path.sub(%r{/}, '')].join '/'

        params[:body] = MultiJson.dump params.fetch(:body, {}) unless params[:body].is_a? String

        params[:headers] ||= {}
        params[:headers]['Content-Type'] = 'application/json' unless params[:headers]['Content-Type']
        params[:headers]['X-Request-ID'] = request_id
        params[:headers]['X-Tiger-Token'] = LittleMonster::Tiger::API.bearer_token

        params[:timeout] ||= LittleMonster.request_timeout

        begin
          res = Typhoeus.public_send method, url, params
          if !res.success? && (res.code < 400 || res.code >= 500)
            raise FuryHttpApiError, "[type:request_failed][request_id:#{request_id}] request to #{res.effective_url} " \
                                    "failed with status #{res.code} code #{res.return_code} retry #{ret}"
          end

          logger.info "[type:request_log][request_id:#{request_id}] request made to #{url} with [status:#{res.code}]"
        rescue StandardError => e
          logger.error e.message
          if ret < retries
            sleep(retry_wait)
            ret += 1
            retry
          end

          logger.error "[type:request_max_retries_reached][request_id:#{request_id}][url:#{url}][retries:#{ret}] request has reached max retries"

          if critical
            logger.error "[type:critical_request_failed][request_id:#{request_id}][url:#{url}][retries:#{ret}] request has reached max retries"
            raise APIUnreachableError,
                  "[request_id:#{request_id}] critical request to #{url} has fail, check little monster api"
          end
        end

        res.define_singleton_method(:body) do
          MultiJson.load(res.options[:response_body], symbolize_keys: true)
        rescue StandardError
          res.options[:response_body]
        end
        res
      end
    end
    class FuryHttpApiError < StandardError; end
  end
end
