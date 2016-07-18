module LittleMonster::Core
  class Job::Factory
    def initialize(message = {})
      @id = message[:id]
      @name = message[:name]
      @tags = message[:tags]

      @api_attributes = fetch_attributes

      #this gets saved for development run and debugging purposes
      @input_data = message[:data]
    end

    def build
      return unless should_build?

      job_class = @name.to_s.camelcase.constantize
      job_class.new job_attributes
    end

    def fetch_attributes
      return {} if %w(development test).include? LittleMonster.env
      resp = API.get "/jobs/#{@id}", {}, retries: LittleMonster.job_requests_retries,
                                         retry_wait: LittleMonster.job_requests_retry_wait,
                                         critical: true

      resp.success? ? resp.body : nil
    end

    def find_current_task
      task_index = @api_attributes.fetch(:tasks, []).find_index do |task|
        task[:status] == 'pending'
      end
      return {} if task_index.nil?

      {
        name: @api_attributes[:tasks][task_index][:name].to_sym,
        retries: @api_attributes[:tasks][task_index][:retries]
      }
    end

    def job_attributes
      attributes = {
        id: @id,
        data: (@api_attributes[:data] || @input_data),
        tags: @tags,
      }

      if %w(development test).include? LittleMonster.env
        attributes
      else
        current_task = find_current_task
        attributes.merge(current_task: current_task[:name],
                         retries: current_task[:retries])

      end
    end

    def should_build?
      !@api_attributes.nil? && @api_attributes.fetch(:status, 'pending') == 'pending'
    end
  end
end
