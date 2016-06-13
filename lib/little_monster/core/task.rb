module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :params
    attr_reader :previous_output
    attr_reader :output

    def initialize(params, previous_output)
      set_default_values params, previous_output
    end

    def run
      raise NotImplementedError, 'You must implement the run method'
    end

    def on_error(error)
    end

    def perform
      logger.debug 'Starting'
      run
      output
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

    def set_default_values(params, previous_output, cancelled_callback = nil)
      @cancelled_callback = cancelled_callback
      @params = params
      @previous_output = previous_output
      @output = {}
    end
  end
end
