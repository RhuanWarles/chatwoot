require 'rails_helper'

RSpec.describe Saas::AiAgent do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:attributes) { { name: 'Sales', system_prompt: "Help customers.\nAsk before acting.", provider: 'openai', model: 'test-model' } }
  let(:agent) { account.saas_ai_agents.build }

  it 'defaults the group blacklist to empty and exposes it in public data' do
    agent.configure!(attributes)
    expect(agent.reload.group_response_blacklist).to eq([])
    expect(agent.public_data['group_response_blacklist']).to eq([])
  end

  it 'normalizes and deduplicates the blacklist and preserves it across unrelated updates' do
    agent.configure!(attributes.merge(group_response_blacklist: ['+55 (62) 99999-1111', '5562999991111']))
    agent.configure!({ name: 'Updated', respond_to_groups: false })
    expect(agent.reload.group_response_blacklist).to eq(['5562999991111'])
    expect(agent.public_data['group_response_blacklist']).to eq(['5562999991111'])
  end

  it 'rejects invalid blacklist values in direct model writes' do
    agent.assign_attributes(attributes)
    [nil, {}, [''], [nil], [123_456_789], ['hello']].each do |value|
      agent.group_response_blacklist = value
      expect(agent).not_to be_valid
      expect(agent.errors.attribute_names).to include(:group_response_blacklist)
    end
  end

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

  it 'defaults to Sao Paulo and rejects unknown timezones' do
    agent.assign_attributes(attributes)
    expect(agent.timezone).to eq(Saas::AiAgent::DEFAULT_TIMEZONE)
    expect(agent).to be_valid

    agent.timezone = 'Mars/Olympus'
    expect(agent).not_to be_valid
    expect(agent.errors.attribute_names).to include(:timezone)
  end

  it 'defaults attachment interpretation to disabled and exposes the setting' do
    agent.configure!(attributes)

    expect(agent.reload.attachment_interpretation_enabled).to be(false)
    expect(agent.public_data).to include('attachment_interpretation_enabled' => false)
  end

  it 'rejects invalid temperature and boolean values' do
    agent.assign_attributes(attributes.merge(temperature: 1.1, active: nil))
    expect(agent).not_to be_valid
    expect(agent.errors.attribute_names).to include(:temperature, :active)
  end

  it 'uses safe response behavior defaults and validates their ranges' do
    agent.assign_attributes(attributes)
    expect(agent.response_delay_seconds).to eq(2)
    expect(agent.split_response_messages).to be(true)
    agent.response_delay_seconds = 11
    agent.split_response_messages = nil
    expect(agent).not_to be_valid
    expect(agent.errors.attribute_names).to include(:response_delay_seconds, :split_response_messages)
  end
end
