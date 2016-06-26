require 'thor'

require_relative './generator'

module LittleMonster
  class Cli < Thor
    desc 'show version','version'
    map %w[-v --version] => :version
    def version
      say '0.0.0'
    end

    desc 'generate', 'generate a new job'
    map %w[g --generate] => :generate

    argument :job_name, 
      type: :string, 
      banner: 'Job Name',
      required: true

    argument :task_names, 
      type: :array, 
      banner: 'A set of instructions for making or preparing something',
      required: true

    def generate
      #generator.destination_root = '/tmp'
      invoke Generator
    end
  end
end
