require 'logger'

module LittleMonster::Core
  module Loggable
    def logger
      @logger ||= TaggedLogger.new
    end
  end
end
