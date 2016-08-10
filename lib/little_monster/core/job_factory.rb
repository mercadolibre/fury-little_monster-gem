module LittleMonster::Core
  class Job::Factory
    include Loggable

    def initialize(message = {})
      @id = message[:id]
      @name = message[:name]

      # it converts tags from array of hashes to a single hash
      @tags = Hash[message.fetch(:tags, []).map { |h| [h.keys.first, h.values.first] }].freeze

      logger.default_tags = @tags.merge(id: @id, name: @name)

      @api_attributes = fetch_attributes.freeze

      # this gets saved for development run and debugging purposes
      @input_data = message[:data]

      begin
        @job_class = @name.to_s.camelcase.constantize
      rescue NameError
        raise JobNotFoundError, "[type:error] job [name:#{@name}] does not exists"
      end
    end

    def build
      if discard?
        logger.info "[type:discard] discarding job with [status:#{(@api_attributes || {}).fetch(:status, 'nil')}]"
        return
      end

      unless LittleMonster.disable_requests?
        notify_job_task_list
        notify_job_max_retries
      end

      @job_class.new job_attributes
    end

    def notify_job_task_list
      return true unless @api_attributes[:tasks].blank?

      params = {
        body: {
          tasks: @job_class.tasks.each_with_index.map { |task, index| { name: task, order: index } }
        }
      }

      res = LittleMonster::API.post "/jobs/#{@id}/tasks", params, retries: LittleMonster.job_requests_retries,
                                                                  retry_wait: LittleMonster.job_requests_retry_wait,
                                                                  critical: true
      res.success?
    end

    def notify_job_max_retries
      return true unless @api_attributes[:max_retries].blank?

      params = {
        body: { max_retries: @job_class.max_retries }
      }

      res = LittleMonster::API.put "/jobs/#{@id}", params, retries: LittleMonster.job_requests_retries,
                                                           retry_wait: LittleMonster.job_requests_retry_wait
      res.success?
    end

    def fetch_attributes
      return {} if LittleMonster.disable_requests?
      resp = API.get "/jobs/#{@id}", {}, retries: LittleMonster.job_requests_retries,
                                         retry_wait: LittleMonster.job_requests_retry_wait,
                                         critical: true

      resp.success? ? resp.body : nil
    end

    def find_current_task
      return { name: @job_class.tasks.first, retries: 0 } if @api_attributes[:tasks].blank?

      task_index = @api_attributes.fetch(:tasks, []).sort_by! { |task| task[:order] }.find_index do |task|
        !Job::ENDED_STATUS.include? task[:status].to_sym
      end
      return {} if task_index.nil?

      {
        name: @api_attributes[:tasks][task_index][:name].to_sym,
        retries: @api_attributes[:tasks][task_index][:retries]
      }
    end

    def calculate_status
      return :pending if @api_attributes[:tasks].blank?
      @api_attributes.fetch(:tasks, []).sort_by! { |task| task[:order] }.each do |task|
        return task[:status].to_sym if task[:status].to_sym != :success
      end
      :success
    end

    def job_attributes
      data = if !@api_attributes[:data].nil?
               @api_attributes[:data]
             else
               @input_data
             end

      attributes = {
        id: @id,
        data: data,
        tags: @tags
      }

      return attributes if LittleMonster.disable_requests?

        status = calculate_status
        current_task = !Job::ENDED_STATUS.include?(status) ? find_current_task : {}

        attributes.merge(status: status,
                         current_task: current_task[:name],
                         retries: current_task[:retries])

    end

    def discard?
      @api_attributes.nil? || Job::ENDED_STATUS.include?(@api_attributes.fetch(:status, :pending).to_sym)
    end
  end
end
