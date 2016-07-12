module LittleMonster::Core
  class Job::Factory
    def initialize(message = {})
      @id = message[:id]
      @name = message[:name]
      @params = message[:params]
      @tags = message[:tags]
    end

    def build
      @api_attributes = fetch_attributes

      return if @api_attributes.fetch(:status, 'pending') != 'pending'


      job_class = @name.to_s.camelcase.constantize
      job_class.new job_attributes
    end

    def fetch_attributes
      return {} if %w(development test).include? LittleMonster.env
      resp = API.get "/job/#{@id}", retries: LittleMonster.job_requests_retries,
                                    retry_wait: LittleMonster.job_requests_retry_wait,
                                    critical: true

      resp.success? ? resp.body : {}
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
      current_task = find_current_task

      attributes = {
        id: @id,
        params: @params,
        tags: @tags,
        data: @api_attributes[:data],
        current_task: current_task[:name],
        retries: current_task[:retries]
      }

      if %w(development test).include? LittleMonster.env
        attributes.delete_if { |_, value| value.nil? }
      else
        attributes
      end
    end
  end
end
