module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :params
    attr_reader :output

    def initialize(params, output)
      set_default_values params, output
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

    def set_default_values(params, output, cancelled_callback = nil)
      @cancelled_callback = cancelled_callback
      @params = params
      @output = output
    end
  end
end
