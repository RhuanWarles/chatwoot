class Workflows::RunJob < ApplicationJob
  queue_as :medium

  def perform(run_id)
    # Only a run that is marked running is picked up, so a duplicate job cannot revive a finished or waiting run.
    run = AutomationWorkflowRun.find_by(id: run_id, status: 'running')
    Workflows::Runner.new(run).perform if run
  end
end
