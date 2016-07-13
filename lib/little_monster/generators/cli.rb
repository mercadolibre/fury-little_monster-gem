require 'thor'
require_relative './conf_gen'
require_relative './generate'

module LittleMonster
  class Cli < Thor

    desc 'show version','version'
    map %w[-v --version] => :version

    def version
      say LittleMonster::VERSION
    end

    desc 'exec <job>','runs a job'
    option :message,
      type: :hash,
      aliases: :m,
      default: {}

    method_option :message,
      aliases: '-m',
      type: :string,
      default: '{}',
      desc: 'Message that will be send as parameter (must be a JSON format)'

    def exec(job)
      require_relative "#{Dir.pwd}/config/application.rb"

      msg = MultiJson.load(options[:message], symbolize_keys: true)
      message = { data: msg, name: job }
      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end

    desc 'start','starts the little monster worker'
    option :daemonize,
      type: :boolean,
      default: false,
      aliases: :d

    def start
      require_relative "#{Dir.pwd}/config/application.rb"

      toiler_args = ['-C', "#{Dir.pwd}/config/toiler.yml"]
      toiler_args += ['-d', '-L', 'log/little_monster.log'] if options[:daemonize]
      Toiler::CLI.instance.run(toiler_args)
    end

    register(LittleMonster::ConfGen, 'init', 'init','Creates new Little Monster Schema app')
    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>...', 'Creates a job with his respective tasks.')
  end
end
