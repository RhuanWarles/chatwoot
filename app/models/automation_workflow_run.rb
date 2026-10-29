class AutomationWorkflowRun < ApplicationRecord
  STATUSES = %w[running waiting completed failed].freeze
  CONTEXT_IDS = %w[deal_id contact_id conversation_id message_id].freeze

  belongs_to :account
  belongs_to :automation_workflow

  validates :status, inclusion: { in: STATUSES }

  scope :due, -> { where(status: 'waiting').where(resume_at: ..Time.current) }

  def as_api_json
    as_json(only: [:id, :status, :trigger_event, :started_at, :finished_at, :error, :trace]).merge('context' => context.slice(*CONTEXT_IDS))
  end
end
