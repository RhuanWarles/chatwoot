class Workflows::ResumeWaitingRunsJob < ApplicationJob
  queue_as :scheduled_jobs

  SWEEP_LIMIT = 500
  RETENTION = 30.days
  STALE_AFTER = 15.minutes

  def perform
    purge_old_runs if Time.current.min.zero?
    AutomationWorkflowRun.due.limit(SWEEP_LIMIT).pluck(:id).each { |id| claim_and_enqueue(id) }
    restart_stale_runs
  end

  private

  # Hourly, because the sweep itself runs every minute.
  def purge_old_runs
    AutomationWorkflowRun.where(status: %w[completed failed], finished_at: ...RETENTION.ago).in_batches.delete_all
  end

  # A run is only `running` while a worker holds it; one that stopped moving lost its worker (or its enqueue).
  def restart_stale_runs
    ids = AutomationWorkflowRun.where(status: 'running', updated_at: ...STALE_AFTER.ago).limit(SWEEP_LIMIT).pluck(:id)
    AutomationWorkflowRun.where(id: ids).update_all(updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    ids.each { |id| Workflows::RunJob.perform_later(id) }
  end

  # The status flip is the claim: an overlapping sweep updates zero rows and enqueues nothing.
  def claim_and_enqueue(id)
    claimed = AutomationWorkflowRun.where(id: id, status: 'waiting').update_all(status: 'running', resume_at: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    Workflows::RunJob.perform_later(id) if claimed == 1
  end
end
