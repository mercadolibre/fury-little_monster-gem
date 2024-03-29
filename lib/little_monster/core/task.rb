module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :data, :job_id, :job_retries, :job_max_retries

    def initialize(data, job_id = nil)
      @data = data
      @job_id = job_id
    end

    def run
      raise NotImplementedError, 'You must implement the run method'
    end

    def on_error(error); end

    def error(e)
      logger.error e
      on_error e
    end

    def is_cancelled?
      @cancelled_callback.nil? ? false : @cancelled_callback.call
    end

    def is_cancelled!
      @cancelled_throw_callback&.call
    end

    def last_retry?
      @retry_callback.nil? ? false : !@retry_callback.call
    end

    private

    def set_default_values(data:, job_id: nil, job_logger: nil,
                           cancelled_callback: nil, cancelled_throw_callback: nil,
                           retries: 0, max_retries: 0, retry_callback: nil)
      @cancelled_callback = cancelled_callback
      @cancelled_throw_callback = cancelled_throw_callback
      @job_id = job_id
      @data = data
      @job_retries = retries
      @job_max_retries = max_retries
      @retry_callback = retry_callback
      logger.parent_logger = job_logger if job_logger
      logger.default_tags.merge!(type: 'task_log')
    end
  end
end
