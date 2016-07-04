class MockJob::TaskA < LittleMonster::Task
  def initialize(params, previous_output)
    super(params, previous_output)
    @my_var = 'task_a_finished'
  end

  def run
    is_cancelled!
    @my_var
  end
end
