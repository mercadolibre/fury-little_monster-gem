require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

    attr_reader :params

    def self.worker_queue(queue)
      toiler_options queue: queue
    end

    def self.worker_concurrency(concurrency)
      toiler_options concurrency: concurrency
    end

    toiler_options auto_visibility_timeout: true,
                   auto_delete: true

    toiler_options parser: MultiJson

    toiler_options on_visibility_extend: (proc do |_, body|
      params = MultiJson.load body['Message'], symbolize_keys: true
      LittleMonster::Job.send_api_heartbeat params[:job_id]
    end)

    def initialize
    end

    def on_message
    end

    def perform(_sqs_msg, body)
      params = MultiJson.load body['Message'], symbolize_keys: true

      on_message

      job_class = params[:job][:name].to_s.camelcase.constantize
      @job = job_class.new(params)

      @job.run
    end
  end
end
