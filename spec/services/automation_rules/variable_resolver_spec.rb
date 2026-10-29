require 'rails_helper'

RSpec.describe AutomationRules::VariableResolver do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Alice', email: 'alice@example.com', custom_attributes: { 'cpf' => '123' }) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Sales') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Qualified', position: 0) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Opportunity', value: 99) }

  it 'resolves standard, custom and CRM variables without raising on missing values' do
    context = AutomationRules::Context.from(account: account, conversation: conversation, deal: deal)

    result = described_class.new(context).resolve(
      '{{contact.name}} {{contact.custom_attributes.cpf}} {{conversation.id}} {{deal.name}} {{deal.pipeline}} {{deal.stage}} {{deal.missing}}'
    )

    expect(result).to include('Alice 123', 'Opportunity', 'Sales', 'Qualified')
    expect(result).to end_with(' ')
  end
end
