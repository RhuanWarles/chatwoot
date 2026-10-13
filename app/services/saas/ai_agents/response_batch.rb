class Saas::AiAgents::ResponseBatch
  KEY = 'ai_agent_response_batch'.freeze

  def self.cancel!(conversation, reason:)
    attributes = conversation.additional_attributes
    batch = attributes[KEY]
    return unless batch.is_a?(Hash) && batch['status'] == 'pending'

    conversation.update!(additional_attributes: attributes.merge(KEY => batch.merge('status' => 'cancelled', 'cancel_reason' => reason)))
  end
end
