module LittleMonster
  require 'active_support/all'

  require 'little_monster/core'
  require 'little_monster/config'

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
      little_monster_api_url: 'http://little_monster_api_url.com/',
      api_request_retries: 4
    }
  end

  def method_missing(method, *args, &block)
    return @@config.public_send(method) if @@config.respond_to? method
    super method, *args, &block
  end
end

LittleMonster.init
