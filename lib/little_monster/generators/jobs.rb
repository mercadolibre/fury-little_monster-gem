module LittleMonster::Generators
  # Creates Jobs class, task_list, and test
  class Jobs
    def initialize(name, *tasks)
      @file_manager = FileManager.new
      @job_name = name.underscore
      @job_tasks = tasks
      @template_file = "#{File.dirname(__FILE__)}/templates/jobs_temp.erb"
      @template_test_file = "#{File.dirname(__FILE__)}/templates/jobs_spec_temp.erb"
    end

    def generate
      @file_manager.prepare_folders(['jobs'])
      generate_jobs_files
      generate_test_files
    end

    def generate_jobs_files
      file_name = "jobs/#{@job_name}.rb"
      template = Tilt.new(@template_file, nil, '-')
      output = template.render(self)
      @file_manager.create_file(file_name, output)
    end

    def generate_test_files
      file_name = "spec/jobs/#{@job_name}_spec.rb"
      template = Tilt.new(@template_test_file, nil, '-')
      output = template.render(self)
      @file_manager.create_file(file_name, output)
    end
  end
end
