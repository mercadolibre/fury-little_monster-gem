module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :data

    def initialize(data)
      @data = data
    end

    def run
      raise NotImplementedError, 'You must implement the run method'
    end

    def on_error(error)
    end

    def error(e)
      logger.error e
      on_error e
    end

    def is_cancelled!
      is_cancelled = false
      is_cancelled = @cancelled_callback.call unless @cancelled_callback.nil?
      raise CancelError if is_cancelled
    end

    private

    def set_default_values(data, job_logger = nil, cancelled_callback = nil)
      @cancelled_callback = cancelled_callback
      @data = data
      logger.parent_logger = job_logger if job_logger
      logger.default_tags.merge!(type: 'task_log')
    end
  end
end
