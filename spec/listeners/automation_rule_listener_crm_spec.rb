require 'rails_helper'

RSpec.describe AutomationRuleListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Sales') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'New', position: 0) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }
  let!(:rule) do
    create(:automation_rule, account: account, event_name: 'crm_deal_created',
           conditions: [{ 'attribute_key' => 'crm_deal_exists', 'filter_operator' => 'is_present', 'values' => [], 'query_operator' => nil }])
  end

  it 'runs rules for CRM deal events with the deal context' do
    allow(AutomationRules::ConditionsFilterService).to receive(:new).and_call_original
    action_service = instance_double(AutomationRules::ActionService, perform: true)
    allow(AutomationRules::ActionService).to receive(:new).and_return(action_service)
    event = Events::Base.new(Events::Types::CRM_DEAL_CREATED, Time.current, { deal: deal, conversation: nil })

    listener.crm_deal_created(event)

    expect(AutomationRules::ActionService).to have_received(:new).with(rule, account, nil, context: an_instance_of(AutomationRules::Context))
  end
end
