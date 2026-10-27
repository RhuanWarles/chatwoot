class Conversations::AiFilterQuery
  def self.active
    <<~SQL.squish
      COALESCE(conversations.additional_attributes ->> 'ai_agent_state', 'active') IN ('active', 'ai')
      AND EXISTS (#{active_agent_assignment})
    SQL
  end

  def self.state
    <<~SQL.squish
      CASE WHEN #{active} THEN 'active' ELSE 'inactive' END
    SQL
  end

  def self.agent(placeholder, assignment_placeholder: placeholder)
    <<~SQL.squish
      (
        EXISTS (#{agent_message_match(placeholder)})
        OR EXISTS (#{agent_assignment_match(assignment_placeholder)})
      )
    SQL
  end

  def self.active_agent_assignment
    <<~SQL.squish
      SELECT 1
      FROM saas_ai_agents
      INNER JOIN saas_ai_agent_inboxes ON saas_ai_agent_inboxes.ai_agent_id = saas_ai_agents.id
      WHERE saas_ai_agents.account_id = conversations.account_id
        AND saas_ai_agents.active = TRUE
        AND saas_ai_agent_inboxes.inbox_id = conversations.inbox_id
    SQL
  end

  def self.agent_message_match(placeholder)
    <<~SQL.squish
      SELECT 1
      FROM messages ai_messages
      WHERE ai_messages.conversation_id = conversations.id
        AND ai_messages.account_id = conversations.account_id
        AND (ai_messages.content_attributes #>> '{}')::jsonb ->> 'ai_agent_id' IN (#{placeholder})
    SQL
  end

  def self.agent_assignment_match(placeholder)
    <<~SQL.squish
      SELECT 1
      FROM saas_ai_agents
      INNER JOIN saas_ai_agent_inboxes ON saas_ai_agent_inboxes.ai_agent_id = saas_ai_agents.id
      WHERE saas_ai_agents.id IN (#{placeholder})
        AND saas_ai_agents.account_id = conversations.account_id
        AND saas_ai_agents.active = TRUE
        AND saas_ai_agent_inboxes.inbox_id = conversations.inbox_id
    SQL
  end

  private_class_method :active_agent_assignment, :agent_message_match, :agent_assignment_match
end
