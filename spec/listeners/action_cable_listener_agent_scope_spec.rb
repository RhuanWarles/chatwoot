require 'rails_helper'

RSpec.describe ActionCableListener, 'agent scope' do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:administrator) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:assignee) { create(:user, account: account, role: :agent) }
  let!(:colleague) { create(:user, account: account, role: :agent) }
  let!(:custom_role_agent) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: assignee) }

  before do
    [assignee, colleague, custom_role_agent].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    custom_role_agent.account_users.find_by(account: account).update!(custom_role: create(:custom_role, account: account))
    Current.user = nil
    Current.account = nil
  end

  it 'tells a conversation only to its assignee, the administrators and the agents whose role decides what they see' do
    expect(ActionCableBroadcastJob).to receive(:perform_later).with(
      a_collection_containing_exactly(assignee.pubsub_token, administrator.pubsub_token, custom_role_agent.pubsub_token),
      'conversation.updated',
      anything
    )

    listener.conversation_updated(Events::Base.new('conversation.updated', Time.zone.now, conversation: conversation))
  end

  it 'does not push the messages of a conversation to a colleague' do
    message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
    expected = a_collection_containing_exactly(assignee.pubsub_token, administrator.pubsub_token, custom_role_agent.pubsub_token,
                                               conversation.contact_inbox.pubsub_token)
    expect(ActionCableBroadcastJob).to receive(:perform_later).with(expected, 'message.created', anything)

    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))
  end

  it 'still tells the previous assignee that the conversation left them' do
    event = Events::Base.new('assignee.changed', Time.zone.now, conversation: conversation,
                                                                changed_attributes: { 'assignee_id' => [colleague.id, assignee.id] })
    expect(ActionCableBroadcastJob).to receive(:perform_later).with(
      a_collection_containing_exactly(assignee.pubsub_token, colleague.pubsub_token, administrator.pubsub_token, custom_role_agent.pubsub_token),
      'assignee.changed',
      anything
    )

    listener.assignee_changed(event)
  end

  it 'does not announce a mention to someone who cannot open the conversation' do
    expect(ActionCableBroadcastJob).not_to receive(:perform_later)

    listener.conversation_mentioned(Events::Base.new('conversation.mentioned', Time.zone.now, conversation: conversation, user: colleague))
  end

  it 'announces a mention to the assignee' do
    expect(ActionCableBroadcastJob).to receive(:perform_later).with([assignee.pubsub_token], 'conversation.mentioned', anything)

    listener.conversation_mentioned(Events::Base.new('conversation.mentioned', Time.zone.now, conversation: conversation, user: assignee))
  end
end
