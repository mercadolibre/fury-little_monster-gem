require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

    toiler_options queue: LittleMonster.worker_queue,
                   concurrency: LittleMonster.worker_concurrency,
                   provider: LittleMonster.worker_provider,
                   provider_config: LittleMonster.worker_provider_config

    toiler_options auto_visibility_timeout: true,
                   auto_delete: true

    toiler_options parser: ->(msg){ MultiJson.load msg.body, symbolize_keys: true }

    def self.update_attributes
      toiler_options queue: LittleMonster.worker_queue,
                     concurrency: LittleMonster.worker_concurrency,
                     provider: LittleMonster.worker_provider,
                     provider_config: LittleMonster.worker_provider_config
    end

    def perform(_sqs_msg, body)
      if LittleMonster.worker_provider == :gcp 
        message = body
      else
        message = MultiJson.load body['Message'], symbolize_keys: true
      end

      LittleMonster::Runner.new(message).run
    end
  end
end
