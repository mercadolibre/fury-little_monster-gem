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

    def generate(*args)
      #generator.destination_root = '/tmp'
      invoke Generator,args
    end
  end
end
