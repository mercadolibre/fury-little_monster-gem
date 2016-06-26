require 'thor'
require_relative './generator'

module LittleMonster
  class Cli < Thor

    desc 'show version','version'
    map %w[-v --version] => :version
    def version
      say '0.0.0'
    end
    
    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>', 'Creates a job with his respective tasks.')
  end
end
