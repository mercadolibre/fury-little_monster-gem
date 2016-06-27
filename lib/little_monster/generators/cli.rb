require 'thor'

require_relative './generate'

module LittleMonster
  class Cli < Thor

    desc 'show version','version'
    map %w[-v --version] => :version
    def version
      say '0.0.0'
    end
    
    desc 'start to run a task','run task'
    argument :job, type: :string
    option :message, type: :string, aliases: :m
    def start
      require_relative "./jobs/#{job}.rb"
      Dir["tasks/*.rb"].each {|file| require_relative file }

      message={params:{"un_parametro":"un valor"},name: job}
      #on_message
      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end


    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>', 'Creates a job with his respective tasks.')
  end
end
