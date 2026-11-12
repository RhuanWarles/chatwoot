require 'rails_helper'

RSpec.describe Crm::Responders do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:replies) { described_class.replies(account) }
  let!(:person) { insert_reply(sender_type: 'User', sender_id: agent.id) }
  let!(:flagged_ai) { insert_reply(sender_type: 'Saas::AiAgent', sender_id: 1, content_attributes: { generated_by_ai: true }) }
  let!(:bot) { insert_reply(sender_type: 'AgentBot', sender_id: 1) }
  let!(:senderless_ai) { insert_reply(content_attributes: { generated_by_ai: true }) }
  let!(:senderless) { insert_reply }

  # Inserted straight into the table: these rows are about what the SQL sees, not about what the model callbacks do.
  def insert_reply(sender_type: nil, sender_id: nil, content_attributes: {})
    # rubocop:disable Rails/SkipsModelValidations
    Message.insert_all([{ account_id: account.id, inbox_id: inbox.id, conversation_id: conversation.id, message_type: 1, private: false,
                          content: 'Reply', sender_type: sender_type, sender_id: sender_id, content_attributes: content_attributes,
                          created_at: Time.current, updated_at: Time.current }], returning: %w[id]).rows.flatten.first
    # rubocop:enable Rails/SkipsModelValidations
  end

  it 'counts a reply from a person, which has no generated_by_ai key at all, as a human reply' do
    expect(described_class.by_humans(replies).pluck(:id)).to eq([person])
  end

  it 'counts flagged AI replies and replies from bots as AI' do
    expect(described_class.by_ai(replies).pluck(:id)).to contain_exactly(flagged_ai, bot, senderless_ai)
  end

  it 'splits the replies so that none is counted on both sides' do
    humans = described_class.by_humans(replies).pluck(:id)
    ai = described_class.by_ai(replies).pluck(:id)

    expect(humans & ai).to be_empty
    expect(humans + ai + [senderless]).to match_array(replies.pluck(:id))
  end

  it 'does not take a person for the AI when the flag is explicitly false' do
    explicit = insert_reply(sender_type: 'User', sender_id: agent.id, content_attributes: { generated_by_ai: false })

    expect(described_class.by_humans(replies).pluck(:id)).to include(explicit)
    expect(described_class.by_ai(replies).pluck(:id)).not_to include(explicit)
  end
end
