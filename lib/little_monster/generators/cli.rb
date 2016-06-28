require 'thor'
require_relative './conf_gen'
require_relative './generate'

module LittleMonster
  class Cli < Thor

    desc 'show version','version'
    map %w[-v --version] => :version
    def version
      say '0.0.0'
    end
    
    desc 'start <job>','runs a job'
    option :message, 
      type: :hash, 
      aliases: :m,
      default: {}

    method_option :message,aliases: '-m', :type => :hash, :default => {}
    def start(job)
      require 'little_monster'
      require_relative "#{Dir.pwd}/jobs/#{job}.rb"
      Dir["#{Dir.pwd}/tasks/#{job}/*.rb"].each {|file| require_relative file }

      message={params:{"un_parametro":"un valor"},name: job}
      #on_message
      job = LittleMonster::Job::Factory.new(options[:message]).build
      job.run unless job.nil?
    end

    register(LittleMonster::ConfGen, 'new', 'new','Creates new Little Monster Schema app')
    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>', 'Creates a job with his respective tasks.')
  end
end
