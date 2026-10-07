class Saas::AiAgent < ApplicationRecord
  self.table_name = 'saas_ai_agents'

  PROVIDERS = Saas::AiSetting::PROVIDERS
  TEMPERATURE_RANGE = 0..1

  belongs_to :account
  has_many :ai_agent_inboxes, class_name: 'Saas::AiAgentInbox', dependent: :destroy, inverse_of: :ai_agent
  has_many :inboxes, through: :ai_agent_inboxes

  validates :name, :system_prompt, :provider, :model, presence: true
  validates :name, :model, length: { maximum: 100 }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :temperature, numericality: { in: TEMPERATURE_RANGE }
  validates :active, :handoff_enabled, inclusion: { in: [true, false] }
  validate :validate_inboxes

  # Serialize assignment and activation together, including concurrent requests.
  def configure!(attributes, selected_inboxes: nil)
    account.with_lock do
      assign_attributes(attributes)
      self.inboxes = selected_inboxes unless selected_inboxes.nil?
      save!
    end
    self
  end

  def public_data
    attributes.slice('id', 'account_id', 'name', 'description', 'system_prompt', 'provider', 'model',
                     'temperature', 'active', 'handoff_enabled', 'created_at', 'updated_at').merge(
                       'temperature' => temperature.to_f,
                       'inboxes' => inboxes.map { |inbox| { id: inbox.id, name: inbox.name } }
                     )
  end

  private

  def validate_inboxes
    errors.add(:inboxes, :invalid) if inboxes.any? { |inbox| inbox.account_id != account_id }
    return unless active?

    occupied = account.saas_ai_agents.where(active: true).where.not(id: id)
                      .joins(:ai_agent_inboxes).where(saas_ai_agent_inboxes: { inbox_id: inboxes.map(&:id) }).exists?
    errors.add(:inboxes, :taken) if occupied
  end
end
