require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

    attr_reader :params

    toiler_options queue: LittleMonster.queue,
                   concurrency: LittleMonster.worker_concurrency,
                   auto_visibility_timeout: true,
                   auto_delete: true

    toiler_options parser: LittleMonster.parser

    def initialize
    end

    def on_message
    end

    def perform(_sqs_msg, body)
      @params = MultiJson.load(body['Message'], symbolize_keys: true)

      on_message

      job_class = job_name.to_s.camelcase.constantize
      @job = job_class.new(params)

      self.class.toiler_options on_visibility_extend: proc do
        @job.send_api_heartbeat unless @job.nil?
      end

      @job.run
    end
  end
end
