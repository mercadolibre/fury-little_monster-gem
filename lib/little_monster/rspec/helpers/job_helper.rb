module LittleMonster::RSpec
  module JobHelper
    class Result
      def initialize(job)
        @job = job

        begin
          job.run
          @retried = false
        rescue LittleMonster::JobRetryError
          @retried = true
        end
      end

      def instance
        @job
      end

      def status
        @job.status
      end

      def retried?
        @retried
      end

      def retries
        @job.instance_variable_get '@retries'
      end

      def data
        @job.data
      end

      def runned_tasks
        @job.instance_variable_get '@runned_tasks'
      end
    end

    def run_job(job, options = {})
      Result.new(generate_job(job, options))
    end

    def generate_job(job, options = {})
      job_class = job.instance_of?(Class) ? job : job.to_s.camelcase.constantize
      job_class.mock!

      job_instance = job_class.new(data: { outputs: options.fetch(:data, {}) })
      job_instance.define_singleton_method(:is_cancelled?) { options.fetch(:cancelled, false) }

      if options[:fails]
        options[:fails] = [options[:fails]] unless options[:fails].is_a? Array
        options[:fails].each do |hash|
          allow_any_instance_of(job_class.task_class_for(hash[:task])).to receive(:run).and_raise(hash.fetch(:error, StandardError.new))
        end
      end

      job_instance
    end
  end
end
