require 'rails_helper'

RSpec.describe Saas::AiAgent do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:attributes) { { name: 'Sales', system_prompt: "Help customers.\nAsk before acting.", provider: 'openai', model: 'test-model' } }
  let(:agent) { account.saas_ai_agents.build }

  it 'creates and edits configuration without truncating the prompt or losing inboxes' do
    agent.configure!(attributes, selected_inboxes: [inbox])
    agent.configure!({ description: 'Updated', system_prompt: 'Long prompt ' * 3000 })
    expect(agent.reload.system_prompt).to eq('Long prompt ' * 3000)
    expect(agent.inboxes).to contain_exactly(inbox)
    expect(agent.active).to be(false)
  end

  it 'rejects inboxes belonging to another account' do
    expect { agent.configure!(attributes, selected_inboxes: [create(:inbox)]) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(account.saas_ai_agents.count).to eq(0)
  end

  it 'allows inactive overlap but blocks competing activation and rolls back changes' do
    first = account.saas_ai_agents.build
    first.configure!(attributes.merge(active: true), selected_inboxes: [inbox])
    agent.configure!(attributes, selected_inboxes: [inbox])
    expect { agent.configure!({ active: true, name: 'Changed' }) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(agent.reload.active).to be(false)
    expect(agent.name).to eq('Sales')
    first.configure!({ active: false })
    agent.configure!({ active: true })
    expect(agent.reload.active).to be(true)
  end

  it 'does not reserve an inbox after unlinking or deleting the agent' do
    agent.configure!(attributes.merge(active: true), selected_inboxes: [inbox])
    agent.configure!({}, selected_inboxes: [])
    expect(Saas::AiAgentInbox.where(ai_agent: agent)).to be_empty
    agent.configure!({}, selected_inboxes: [inbox])
    agent.destroy!
    expect(Saas::AiAgentInbox.where(inbox: inbox)).to be_empty
  end

  it 'validates mandatory fields and supported providers' do
    expect(agent).not_to be_valid
    expect(agent.errors.attribute_names).to include(:name, :system_prompt, :provider, :model)
    agent.assign_attributes(attributes.merge(provider: 'unsupported'))
    expect(agent).not_to be_valid
  end

  it 'rejects invalid temperature and boolean values' do
    agent.assign_attributes(attributes.merge(temperature: 1.1, active: nil))
    expect(agent).not_to be_valid
    expect(agent.errors.attribute_names).to include(:temperature, :active)
  end
end
