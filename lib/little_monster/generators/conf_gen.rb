require 'thor'
require 'active_support/core_ext/string'

module LittleMonster
  class ConfGen < Thor::Group
    include Thor::Actions

    def self.source_root
      File.dirname(__FILE__)
    end

    def create_conf_file
      directory('./templates/config','config')
    end

    def create_tasks_file
        template 'templates/spec_helper_temp.erb',"spec/spec_helper.rb"
    end
  end
end
