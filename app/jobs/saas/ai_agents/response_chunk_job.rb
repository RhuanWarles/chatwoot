class Saas::AiAgents::ResponseChunkJob < ApplicationJob
  queue_as :low

  def perform(account_id, conversation_id, batch_id, chunk_index, first_message_id = nil)
    conversation = Account.find(account_id).conversations.find(conversation_id)
    message = conversation.with_lock do
      batch = conversation.additional_attributes[Saas::AiAgents::ResponseBatch::KEY]
      if batch.blank? || batch['id'] != batch_id || batch['status'] != 'pending'
        return log(conversation, batch, 'cancelled')
      end

      return log(conversation, batch, 'cancelled_out_of_order', chunk_index: chunk_index.to_i) if batch['sent_count'].to_i != chunk_index.to_i

      if Saas::AiAgents::Context.latest_incoming(conversation)&.id != batch['incoming_message_id'].to_i ||
         !Saas::AiAgents::Runtime.enabled?(conversation) || Saas::AiAgents::Runtime.agent_for(conversation)&.id != batch['agent_id'].to_i
        Saas::AiAgents::ResponseBatch.cancel!(conversation, reason: 'stale')
        return log(conversation, batch, 'cancelled_stale')
      end

      chunks = Array(batch['chunks'])
      content = chunks[chunk_index.to_i]
      return unless content

      agent = conversation.account.saas_ai_agents.find(batch['agent_id'])
      if chunk_index.to_i.zero?
        conversation.messages.find(first_message_id)
      else
        Messages::MessageBuilder.new(agent, conversation, {
                                       content: content, message_type: 'outgoing', private: false, content_type: 'text', defer_send: true,
                                       content_attributes: batch['content_attributes'].merge(
                                         'ai_response_batch_id' => batch_id, 'ai_response_chunk_index' => chunk_index.to_i,
                                         'ai_response_chunk_count' => chunks.length
                                       )
                                     }).perform
      end
    end

    SendReplyJob.perform_now(message.id)
    conversation.with_lock do
      batch = conversation.additional_attributes[Saas::AiAgents::ResponseBatch::KEY]
      return log(conversation, batch, 'cancelled') if batch.blank? || batch['id'] != batch_id || batch['status'] != 'pending'

      chunks = Array(batch['chunks'])
      sent_count = chunk_index.to_i + 1
      status = sent_count >= chunks.length ? 'completed' : 'pending'
      conversation.update!(additional_attributes: conversation.additional_attributes.merge(
        Saas::AiAgents::ResponseBatch::KEY => batch.merge('sent_count' => sent_count, 'status' => status)
      ))
      log(conversation, batch, status == 'completed' ? 'chunk_completed' : 'chunk_sent', chunk_index: chunk_index.to_i)
      schedule_next_chunk(conversation, batch_id, sent_count, first_message_id) if status == 'pending'
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  private

  def log(conversation, batch, status, chunk_index: nil)
    Rails.logger.info({ event: 'ai_agent_runtime', account_id: conversation.account_id, conversation_id: conversation.id,
                        incoming_message_id: batch&.fetch('incoming_message_id', nil), ai_agent_id: batch&.fetch('agent_id', nil),
                        batch_id: batch&.fetch('id', nil), chunk_index: chunk_index, status: status }.compact.to_json)
  end

  def schedule_next_chunk(conversation, batch_id, chunk_index, first_message_id)
    delay = Saas::AiAgents::MessageSplitter.delay_for(chunk_index).seconds * chunk_index
    self.class.set(wait: delay).perform_later(conversation.account_id, conversation.id, batch_id, chunk_index, first_message_id)
  end
end
