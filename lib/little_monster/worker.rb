require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

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
      logger.debug 'sending heartbeat'
      #message = MultiJson.load body['Message'], symbolize_keys: true
      #send heartbeat
      #LittleMonster::Job.send_api_heartbeat message[:job_id]
    end)

    def initialize
    end

    def on_message
    end

    def perform(_sqs_msg, body)
      message = MultiJson.load body['Message'], symbolize_keys: true
      message[:params] = MultiJson.load message[:params], symbolize_keys: true

      on_message

      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end
  end
end
