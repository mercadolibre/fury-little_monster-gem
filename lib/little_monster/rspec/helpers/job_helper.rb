module LittleMonster::RSpec
  module JobHelper
    class Result
      def initialize(job)
        @job = job
        job.run
      end

      def instance
        @job
      end

      def status
        @job.status
      end

      def retries
        @job.instance_variable_get '@retries'
      end

      def output
        @job.output
      end

      def runned_tasks
        @job.instance_variable_get '@runned_tasks'
      end
    end

    def run_job(job, options = {})
      job_class = job.class == Class ? job : job.to_s.camelcase.constantize
      job_class.mock!

      job_instance = job_class.new(options[:params])
      job_instance.define_singleton_method(:is_cancelled?) { options.fetch(:cancelled, false) }
      job_instance.instance_variable_set('@retries', options[:retry]) if options[:retry]

      if options[:fails]
        options[:fails] = [options[:fails]] unless options[:fails].is_a? Array
        options[:fails].each do |hash|
          allow_any_instance_of(job_class.task_class_for(hash[:task])).to receive(:run).and_raise(hash.fetch(:error, StandardError.new))
        end
      end

      Result.new(job_instance)
    end
  end
end
