class MockJob::TaskB < LittleMonster::Task
  def run
    data[:task_b] = 'task_b_finished'
  end
end
