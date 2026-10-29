class AutomationWorkflow < ApplicationRecord
  TRIGGER_EVENTS = %w[
    conversation_created conversation_opened conversation_resolved message_created assignee_changed team_changed
    contact_created contact_updated crm_deal_created crm_deal_updated crm_deal_stage_changed crm_deal_status_changed
    crm_deal_pipeline_changed crm_deal_field_changed crm_deal_won crm_deal_lost webhook manual
  ].freeze

  belongs_to :account
  has_many :runs, class_name: 'AutomationWorkflowRun', dependent: :delete_all

  has_secure_token :webhook_token, length: 32

  before_validation :sync_trigger_events

  validates :name, presence: true, length: { maximum: 120 }
  validate :graph_is_valid
  validate :active_workflow_has_trigger

  scope :active, -> { where(active: true) }

  def graph_model
    Workflows::Graph.new(graph)
  end

  private

  def sync_trigger_events
    graph = graph_model
    self.trigger_events = graph.triggers.filter_map { |node| graph.event_of(node) }.uniq
  end

  def graph_is_valid
    graph_model.errors.each { |message| errors.add(:graph, message) }
  end

  def active_workflow_has_trigger
    errors.add(:graph, 'needs at least one trigger to be activated') if active? && trigger_events.empty?
  end
end
