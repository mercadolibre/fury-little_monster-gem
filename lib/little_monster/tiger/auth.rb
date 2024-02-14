require 'jwt'
require 'typhoeus'

module LittleMonster
  module Tiger
    module API
      module_function

      def bearer_token
        token = new_shark_token
        "Bearer #{token}" if token
      end

      def new_shark_token
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
