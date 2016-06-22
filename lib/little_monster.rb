require 'active_support/all'
require 'multi_json'
require 'little_monster/config'
require 'little_monster/core'

module LittleMonster
  include LittleMonster::Core

  module_function

  def init
    @@config = Config.new default_config_values

    @@env = ActiveSupport::StringInquirer.new(ENV['LITTLE_MONSTER_ENV'] || ENV['RUBY_ENV'] || 'development')
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
      api_request_retries: 4
    }
  end

  def method_missing(method, *args, &block)
    return @@config.public_send(method) if @@config.respond_to? method
    super method, *args, &block
  end
end

LittleMonster.init

# once all the core and configs were loaded we can require the worker
require 'little_monster/worker'
