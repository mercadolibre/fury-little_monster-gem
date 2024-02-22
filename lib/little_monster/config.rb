module LittleMonster
  class Config
    attr_accessor :api_url, :worker_concurrency, :worker_queue, :worker_provider, :formatter, :request_timeout,
                  :default_request_retries, :default_request_retry_wait, :task_requests_retries, :task_requests_retry_wait,
                  :job_requests_retries, :job_requests_retry_wait, :heartbeat_execution_interval, :default_job_retries,
                  :tiger_api_url, :shark_login_file_path, :enable_tiger_token

    def initialize(params = {})
      params.to_hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end
