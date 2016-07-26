require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

    toiler_options queue: LittleMonster.worker_queue,
                   concurrency: LittleMonster.worker_concurrency

    toiler_options auto_visibility_timeout: true,
                   auto_delete: true

    toiler_options parser: MultiJson

    def self.update_attributes
      toiler_options queue: LittleMonster.worker_queue,
                     concurrency: LittleMonster.worker_concurrency
    end

    def perform(_sqs_msg, body)
      message = MultiJson.load body['Message'], symbolize_keys: true
      message[:data] = MultiJson.load message[:data], symbolize_keys: true

      LittleMonster::Runner.new(message).run
    end
  end
end
