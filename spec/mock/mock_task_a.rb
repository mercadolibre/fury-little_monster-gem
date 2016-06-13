class MockJob::TaskA < LittleMonster::Task
  def initialize(params, previous_output)
    super(params, previous_output)
    @my_var = 'task_a_finished'
  end

  def run
    output[:mock_task_a] = @my_var
    is_cancelled!
  end
end
