require 'fileutils'
require 'rainbow'
require 'active_support/inflector'

module LittleMonster::Generators
  # Creates and check files
  class FileManager
    def prepare_folders(folders)
      folders.each do |folder|
        FileUtils.mkdir_p(folder)
        FileUtils.mkdir_p("spec/#{folder}")
      end
    end

    def create_file(f_name, output)
      ret = false
      if File.exist?(f_name)
        puts Rainbow("File skiped: #{f_name}").yellow
      else
        write_files(f_name, output)
        puts Rainbow("File created: #{f_name}").green
        ret = true
      end
      ret
    end

    private

    def write_files(f_name, output)
      File.open(f_name, 'w', 0644) do |f|
        f.write output
        f.flush
      end
    end
  end
end
