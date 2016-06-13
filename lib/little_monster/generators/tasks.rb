module LittleMonster::Generators
  # Creates all tasks and test files
  class Tasks
    def initialize(job_name, *names)
      @file_manager = FileManager.new
      @job_name = job_name
      @tasks_names = names.map(&:underscore)
      @template_file = "#{File.dirname(__FILE__)}/templates/tasks_temp.erb"
      @template_test_file = "#{File.dirname(__FILE__)}/templates/tasks_spec_temp.erb"
      @tasks_folder = "tasks/#{@job_name}"
    end

    def generate
      @file_manager.prepare_folders([@tasks_folder])
      generate_tasks_files
      generate_tests_files
    end

    def generate_tasks_files
      @tasks_names.each do |name|
        @current_task_name = name
        file_name = "#{@tasks_folder}/#{@current_task_name}.rb"
        template = Tilt.new(@template_file, nil, '-')
        output = template.render(self)
        @file_manager.create_file(file_name, output)
      end
    end

    def generate_tests_files
      @tasks_names.each do |name|
        @current_task_name = name
        file_name = "spec/#{@tasks_folder}/#{@current_task_name}_spec.rb"
        template = Tilt.new(@template_test_file, nil, '-')
        output = template.render(self)
        @file_manager.create_file(file_name, output)
      end
    end
  end
end
