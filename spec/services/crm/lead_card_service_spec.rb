require 'rails_helper'

RSpec.describe Crm::LeadCardService do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:first_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def perform(**options)
    described_class.new(contact: contact, **options).perform
  end

  it 'creates the card of a new lead in the first stage of the default pipeline' do
    expect { perform(conversation: conversation) }.to change { account.crm_deals.count }.by(1)

    expect(account.crm_deals.last).to have_attributes(contact_id: contact.id, pipeline_id: pipeline.id, pipeline_stage_id: first_stage.id,
                                                      name: 'Maria', status: 'open', owner_id: nil)
  end

  it 'gives the card to the agent assigned to the conversation' do
    conversation.update!(assignee: agent)

    perform(conversation: conversation)

    expect(account.crm_deals.last.owner_id).to eq(agent.id)
  end

  it 'does not create a second card while the contact has an open one' do
    perform(conversation: conversation)

    expect { perform(conversation: conversation) }.not_to(change { account.crm_deals.count })
  end

  it 'creates a new card when the contact only has closed ones' do
    perform(conversation: conversation)
    account.crm_deals.last.update!(status: 'won')

    expect { perform(conversation: conversation) }.to change { account.crm_deals.count }.by(1)
  end

  it 'does nothing when the account has no usable pipeline' do
    pipeline.update!(active: false)

    expect { perform }.not_to(change { account.crm_deals.count })
  end

  it 'does nothing when automatic cards are turned off' do
    Crm::AutoCardSettings.new(account).update!(enabled: false, pipeline_id: nil, stage_id: nil)

    expect { perform }.not_to(change { account.crm_deals.count })
  end

  it 'skips blocked contacts and groups' do
    contact.update!(blocked: true)
    expect { perform }.not_to(change { account.crm_deals.count })

    group = create(:contact, account: account, identifier: '120363000000000000@g.us', additional_attributes: { 'is_group' => true })
    expect { described_class.new(contact: group).perform }.not_to(change { account.crm_deals.count })
  end

  it 'uses the pipeline of the AI agent that answers the conversation' do
    other_pipeline = account.crm_pipelines.create!(name: 'IA')
    other_stage = account.crm_pipeline_stages.create!(pipeline: other_pipeline, name: 'Triagem', position: 0)
    allow(Saas::AiAgents::Runtime).to receive(:agent_for).with(conversation).and_return(instance_double(Saas::AiAgent, crm_pipeline_id: other_pipeline.id))

    perform(conversation: conversation)

    expect(account.crm_deals.last).to have_attributes(pipeline_id: other_pipeline.id, pipeline_stage_id: other_stage.id)
  end
end
