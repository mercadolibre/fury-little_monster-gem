class MockJob::TaskB < LittleMonster::Task
  def run
    output[:mock_task_b] = 'task_b_finished'
    output.merge! @previous_output
  end
end
