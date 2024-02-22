require 'jwt'
require 'typhoeus'

module LittleMonster
  module Tiger
    module API
      module_function

      def bearer_token
        token = cached_shark_token
        "Bearer #{token}" if token
      end

      def cached_shark_token
        shark_token = Cache.instance.get(:shark_token)
        return shark_token if shark_token

        shark_token = new_shark_token
        return nil if shark_token.nil?
        Cache.instance.set(:shark_token, shark_token, 60 * 60)
        shark_token
      end

      def new_shark_token
        return nil unless LittleMonster.enable_tiger_token
        shark_token = File.read(LittleMonster.shark_login_file_path)
        response = make_call(:post, 'login/shark', body: { token: shark_token }.to_json)
        return nil if response.failure?

        MultiJson.load(response.body, symbolize_keys: true)[:token]
      end

      def make_call(method, endpoint, options = {})
        Typhoeus::Request.new(
          "#{LittleMonster.tiger_api_url}/#{endpoint}",
          method: method,
          params: options[:params],
          headers: { 'Content-Type': 'application/json' },
          body: options[:body]
        ).run
      end
    end
  end
end
