require 'thor'
require 'active_support/core_ext/string'

module LittleMonster
  class ConfGen < Thor::Group
    include Thor::Actions

    def self.source_root
      File.dirname(__FILE__)
    end

    def create_conf_files
      directory('./templates/config','config')
    end

    def create_lib_files
      directory('./templates/lib','lib')
    end

    def create_log_files
      directory('./templates/log','log')
    end

    def create_specs_files
      template 'templates/spec_helper_temp.erb',"spec/spec_helper.rb"
    end
  end
end
