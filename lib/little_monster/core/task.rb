module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :params
    attr_reader :data

    def initialize(params, data)
      set_default_values params, data
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

    def set_default_values(params, data, job_logger=nil, cancelled_callback=nil)
      @cancelled_callback = cancelled_callback
      @params = params
      @data = data
      @logger = job_logger if job_logger
    end
  end
end
