module LittleMonster
  class Config
    attr_accessor :api_url
    attr_accessor :api_request_retries

    attr_accessor :worker_concurrency
    attr_accessor :worker_queue
    
    attr_accessor :default_formatter

    def initialize(params = {})
      params.to_hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end
