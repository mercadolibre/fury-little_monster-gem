class MockJob::TaskA < LittleMonster::Task
  def initialize(data)
    super(data)
    @my_var = 'task_a_finished'
  end

  def run
    is_cancelled!
    @my_var
  end
end
