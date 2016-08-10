module LittleMonster::Core
  class JobNotFoundError < StandardError
    def initialize(job_id)
      params = {
        body: {
          status: 'error'
        }
      }
      LittleMonster::API.put "/jobs/#{job_id}", params,
            retries: LittleMonster.job_requests_retries,
            retry_wait: LittleMonster.job_requests_retry_wait,
            critical: true
    end
  end
end
