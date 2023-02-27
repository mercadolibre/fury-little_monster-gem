module LittleMonster::Core
  class TaggedLogger
    attr_accessor :parent_logger
    attr_reader :tags

    LEVELS = %i[unknown fatal error warn info debug].freeze

    def self.tags_to_string(hash)
      hash.map { |k, v| "[#{k}:#{v}]" }.join
    end

    def initialize
      @tags = Hash.new({})
      @parent_logger = nil
    end

    def method_missing(method, *args, &block)
      if method.to_s.ends_with? 'tags='
        tag_key = method.to_s.split('_').first.to_sym
        return public_send('tags_for', tag_key, *args) if LEVELS.include? tag_key
      end

      if method.to_s.ends_with? 'tags'
        tag_key = method.to_s.split('_').first.to_sym
        return @tags[tag_key] if LEVELS.include? tag_key
      end

      return LittleMonster.logger.public_send method, tag_message(method.to_sym, *args) if LEVELS.include? method.to_sym

      super method, *args, &block
    end

    def tags_for(key, t = {})
      @tags[key] = t
    end

    def default_tags
      @tags[:default]
    end

    def default_tags=(t)
      tags_for(:default, t)
    end

    def tag_message(level, message = '')
      prefix_string =  tags_to_string @tags[:default].merge(@tags[level])
      prefix_string << ' -- ' unless prefix_string.blank?

      prefix_string = @parent_logger.tag_message level, prefix_string unless @parent_logger.nil?

      [prefix_string, message].join
    end

    def log_tags(level, tags_hash)
      public_send(level, tags_to_string(tags_hash))
    end

    def tags_to_string(hash)
      self.class.tags_to_string hash
    end
  end
end
