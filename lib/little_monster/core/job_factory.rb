module LittleMonster::Core
  class Job::Factory
    def initialize(message={})
      @id = message[:id]
      @name = message[:name]
      @params = message[:params]
      @tags = message[:tags]
    end

    def build
      @api_attributes = fetch_attributes

      return if @api_attributes.fetch(:status, 'pending') != 'pending'

      current_task = find_current_task

      job_attributes = {
        id: @id,
        params: @params,
        tags: @tags,
        current_task: current_task[:name],
        retries: current_task[:retries],
        last_output: current_task[:previous_output]
      }.delete_if { |_,value| value.nil? }


      job_class = @name.to_s.camelcase.constantize
      job_class.new job_attributes
    end

    def fetch_attributes
      #resp = API.get "/job/#{@id}"
      {}
    end

    def find_current_task
      task_index = @api_attributes.fetch(:tasks, []).find_index do |task|
        task[:status] == 'pending'
      end
      return {} if task_index.nil?

      {
        name: @api_attributes[:tasks][task_index][:name],
        retries: @api_attributes[:tasks][task_index][:retries],
        previous_output: (task_index > 0 ? @api_attributes[:tasks][task_index-1][:output] : nil)
      }
    end
  end
end
