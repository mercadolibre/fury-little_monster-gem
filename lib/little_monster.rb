require 'active_support/all'
require 'multi_json'
require 'little_monster/config'
require 'little_monster/core'

module LittleMonster
  include LittleMonster::Core

  module_function

  def init
    @@config = Config.new default_config_values
  end

  def configure
    yield @@config
  end

  def default_config_values
    {
      api_url: 'http://little_monster_api_url.com/',
      api_request_retries: 4,
      parser: ::MultiJson,
      queue: 'little_monster_default_queue',
      worker_concurrency: 5
    }
  end

  def method_missing(method, *args, &block)
    return @@config.public_send(method) if @@config.respond_to? method
    super method, *args, &block
  end
end

LittleMonster.init

#once all the core and configs were loaded we can require the worker
require 'little_monster/worker'
