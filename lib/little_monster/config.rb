module LittleMonster
  class Config
    attr_accessor :api_url

    attr_accessor :worker_concurrency
    attr_accessor :worker_queue
    attr_accessor :worker_provider
    attr_accessor :worker_provider_config

    attr_accessor :formatter

    attr_accessor :request_timeout

    attr_accessor :default_request_retries
    attr_accessor :default_request_retry_wait

    attr_accessor :task_requests_retries
    attr_accessor :task_requests_retry_wait

    attr_accessor :job_requests_retries
    attr_accessor :job_requests_retry_wait

    attr_accessor :heartbeat_execution_interval

    attr_accessor :default_job_retries

    def initialize(params = {})
      params.to_hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end
