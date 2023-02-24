class MockJobExtension::TaskB < LittleMonster::Task
  def run
    data[:task_b] = 'task_b_finished_by_extension'
  end
end
