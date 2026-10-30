require 'rails_helper'

RSpec.describe Crm::DealOwnerSyncService do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:previous_agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact, assignee: agent) }

  def create_deal(**attributes)
    account.crm_deals.create!({ pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead' }.merge(attributes))
  end

  it 'moves the open cards of the contact to the assigned agent' do
    ownerless = create_deal
    owned_by_previous = create_deal(owner: previous_agent)

    described_class.new(conversation: conversation).perform

    expect([ownerless, owned_by_previous].map { |deal| deal.reload.owner_id }).to eq([agent.id, agent.id])
  end

  it 'leaves closed cards and the cards of other contacts alone' do
    won = create_deal(status: 'won', owner: previous_agent)
    other = account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Outro')

    described_class.new(conversation: conversation).perform

    expect(won.reload.owner_id).to eq(previous_agent.id)
    expect(other.reload.owner_id).to be_nil
  end

  it 'does nothing when the conversation is unassigned' do
    deal = create_deal(owner: previous_agent)
    conversation.update!(assignee: nil)

    described_class.new(conversation: conversation).perform

    expect(deal.reload.owner_id).to eq(previous_agent.id)
  end
end
