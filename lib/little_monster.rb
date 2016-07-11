require 'active_support/all'
require 'multi_json'
require 'toiler'
require 'little_monster/config'
require 'little_monster/core'

module LittleMonster
  include LittleMonster::Core

  module_function

  def init
    @@config = Config.new default_config_values

    @@env = ActiveSupport::StringInquirer.new(ENV['LITTLE_MONSTER_ENV'] || ENV['RUBY_ENV'] || 'development')

    @@logger = @@env.test? ? Logger.new('/dev/null') : Toiler.logger
  end

  def env
    @@env
  end

  def configure
    yield @@config
  end

  def default_config_values
    {
      api_url: 'http://little_monster_api_url.com/',
      worker_concurrency: 200,
      worker_queue: nil,
      request_timeout: 3,
      default_request_retries: 4,
      default_request_retry_wait: 1,
      task_requests_retries: 4,
      task_requests_retry_wait: 1,
      job_requests_retries: 4,
      job_requests_retry_wait: 1
    }
  end

  def logger
    @@logger
  end

  def method_missing(method, *args, &block)
    return @@config.public_send(method) if @@config.respond_to? method
    super method, *args, &block
  end
end

LittleMonster.init

# once all the core and configs were loaded we can require the worker
require 'little_monster/worker'
