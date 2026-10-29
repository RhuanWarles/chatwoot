require 'rails_helper'

RSpec.describe Workflows::ResumeWaitingRunsJob do
  let(:account) { create(:account) }
  let(:workflow) { account.automation_workflows.create!(name: 'Espera', graph: { 'nodes' => [], 'edges' => [] }) }

  def create_run(**attributes)
    workflow.runs.create!({ account_id: account.id, trigger_event: 'manual', started_at: Time.current }.merge(attributes))
  end

  it 'claims the runs whose wait is over and enqueues them once' do
    due = create_run(status: 'waiting', resume_at: 1.minute.ago)
    later = create_run(status: 'waiting', resume_at: 1.hour.from_now)

    expect { described_class.perform_now }.to have_enqueued_job(Workflows::RunJob).with(due.id).once

    expect(due.reload).to have_attributes(status: 'running', resume_at: nil)
    expect(later.reload.status).to eq('waiting')
  end

  it 'restarts a run that stopped moving while running' do
    stale = create_run(status: 'running')
    stale.update_columns(updated_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    fresh = create_run(status: 'running')

    expect { described_class.perform_now }.to have_enqueued_job(Workflows::RunJob).with(stale.id)
    expect(Workflows::RunJob).not_to have_been_enqueued.with(fresh.id)
  end

  it 'only runs a job for a run that is marked running' do
    finished = create_run(status: 'completed', finished_at: Time.current)
    allow(Workflows::Runner).to receive(:new)

    Workflows::RunJob.perform_now(finished.id)

    expect(Workflows::Runner).not_to have_received(:new)
  end

  it 'deletes old finished runs on the hour' do
    old = create_run(status: 'completed', finished_at: 40.days.ago)
    recent = create_run(status: 'completed', finished_at: 1.day.ago)

    travel_to(Time.current.beginning_of_hour) { described_class.perform_now }

    expect(AutomationWorkflowRun.exists?(old.id)).to be(false)
    expect(AutomationWorkflowRun.exists?(recent.id)).to be(true)
  end
end
