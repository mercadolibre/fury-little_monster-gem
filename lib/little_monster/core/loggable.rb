require 'logger'

module LittleMonster::Core
  module Loggable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def logger
        if !defined?(@logger) || @logger.nil?
          if superclass.include? Loggable
            parent_logger = superclass.logger
            output = parent_logger.instance_variable_get(:'@logdev').filename || STDOUT
            initialize_logger(output)
          else
            initialize_logger STDOUT
          end
        end

        @logger
      end

      def initialize_logger(file, formatter = nil)
        return @logger = Logger.new('/dev/null') if LittleMonster.env.test?

        @logger = Logger.new(file)
        @logger.progname = to_s.underscore
        @logger.formatter = if formatter
                              formatter
                            else
                              default_formatter
                            end
      end

      def default_formatter
        return LittleMonster.default_formatter if LittleMonster.default_formatter
        proc do |severity, datetime, _progname, msg|
          date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
          "#{date_format} -  [level:#{severity}]  (#{to_s.underscore}): #{msg}\n"
        end
      end
    end

    def logger
      self.class.logger
    end
  end
end
