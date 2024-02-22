require 'moneta'

module LittleMonster
  module Tiger
    class Cache
      include Singleton

      attr_reader :cache

      def initialize
        @cache = Moneta.new(:Memory, expires: true)
      end

      def set(key, value, expires = 0)
        @cache.store(key, value, expires: expires)
      end

      def get(key)
        @cache[key]
      end

      def clear
        @cache.clear
      end
    end
  end
end
