class Saas::AiAgent < ApplicationRecord
  self.table_name = 'saas_ai_agents'

  PROVIDERS = Saas::AiSetting::PROVIDERS
  TEMPERATURE_RANGE = 0..1

  belongs_to :account
  has_many :messages, as: :sender, dependent: :nullify
  has_many :ai_agent_inboxes, class_name: 'Saas::AiAgentInbox', dependent: :destroy, inverse_of: :ai_agent
  has_many :inboxes, through: :ai_agent_inboxes
  has_many :memories, class_name: 'Saas::AiAgentMemory', dependent: :destroy
  has_many :ai_tool_agents, class_name: 'Saas::AiToolAgent', dependent: :destroy
  has_many :tools, through: :ai_tool_agents, source: :ai_tool
  has_many :knowledge_links, class_name: 'Saas::AiAgentKnowledgeBase', dependent: :destroy
  has_many :knowledge_bases, through: :knowledge_links, source: :knowledge_base

  validates :name, :system_prompt, :provider, :model, presence: true
  validates :name, :model, length: { maximum: 100 }
  validates :system_prompt, length: { minimum: 1 }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :temperature, numericality: { in: TEMPERATURE_RANGE }
  validates :context_messages_limit, numericality: { only_integer: true, in: 1..100 }
  validates :response_delay_seconds, numericality: { only_integer: true, in: 0..10 }
  validates :max_messages_per_response, numericality: { only_integer: true, in: 1..5 }
  validates :split_response_messages, :active, :handoff_enabled, :respond_to_groups, :customer_memory_enabled, inclusion: { in: [true, false] }
  validate :validate_inboxes
  validate :validate_runtime_provider

  # Serialize assignment and activation together, including concurrent requests.
  def configure!(attributes, selected_inboxes: nil, selected_tools: nil, selected_knowledge_bases: nil)
    account.with_lock do
      assign_attributes(attributes)
      self.inboxes = selected_inboxes unless selected_inboxes.nil?
      self.knowledge_bases = selected_knowledge_bases unless selected_knowledge_bases.nil?
      if selected_tools
        ai_tool_agents.delete_all
        selected_tools.each { |tool| ai_tool_agents.create!(account: account, ai_tool: tool) }
      end
      save!
    end
    self
  end

  def public_data
    attributes.slice('id', 'account_id', 'name', 'description', 'system_prompt', 'provider', 'model',
                     'temperature', 'context_messages_limit', 'response_delay_seconds', 'split_response_messages', 'active', 'handoff_enabled', 'respond_to_groups', 'customer_memory_enabled', 'created_at', 'updated_at').merge(
                       'temperature' => temperature.to_f,
                       'inboxes' => inboxes.map { |inbox| { id: inbox.id, name: inbox.name } },
                       'knowledge_bases' => knowledge_bases.map { |base| { id: base.id, name: base.name, active: base.active } },
                       'tools' => tools.map { |tool| { id: tool.id, name: tool.name, slug: tool.slug, description: tool.description, active: tool.active, allow_in_playground: tool.allow_in_playground } }
                     )
  end

  def push_event_data
    { id: id, name: name, type: 'agent_bot', avatar_url: nil }
  end

  def webhook_data
    push_event_data
  end

  private

  def validate_inboxes
    errors.add(:inboxes, :invalid) if inboxes.any? { |inbox| inbox.account_id != account_id }
    return unless active?

    occupied = account.saas_ai_agents.where(active: true).where.not(id: id)
                      .joins(:ai_agent_inboxes).where(saas_ai_agent_inboxes: { inbox_id: inboxes.map(&:id) }).exists?
    errors.add(:inboxes, :taken) if occupied
  end

  def validate_runtime_provider
    return unless active? && account
    return if (account.saas_ai_setting&.text_mode || 'platform') == 'platform'
    return if provider == 'openai'

    errors.add(:provider, :invalid)
  end
end
