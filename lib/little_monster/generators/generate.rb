require 'thor'
require 'active_support/core_ext/string'

module LittleMonster
  class Generate < Thor::Group
    include Thor::Actions

    argument :job_name, 
      type: :string, 
      banner: 'Job Name',
      required: true

    argument :task_names, 
      type: :array, 
      banner: 'A set of instructions for making or preparing something',
      required: true

    def self.source_root
      File.dirname(__FILE__)
    end

    def create_job_file
      template('templates/jobs_temp.erb', "jobs/#{job_name}.rb")
      template 'templates/jobs_spec_temp.erb',"spec/jobs/#{job_name}_spec.rb"
    end

    def create_tasks_file
      task_names.each do |task|
        @current_task_name=task
        template('templates/tasks_temp.erb', "tasks/#{job_name}/#{task}.rb")
        template 'templates/tasks_spec_temp.erb',"spec/tasks/#{job_name}/#{task}_spec.rb"
      end
    end
  end
end
