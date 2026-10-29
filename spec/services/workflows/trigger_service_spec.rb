require 'rails_helper'

RSpec.describe Workflows::TriggerService do
  let(:account) { create(:account) }
  let(:graph) do
    {
      'nodes' => [{ 'id' => 't', 'type' => 'trigger', 'data' => { 'event' => 'crm_deal_lost' } },
                  { 'id' => 'a', 'type' => 'action', 'data' => { 'action' => 'set_variable', 'params' => { 'name' => 'x', 'value' => '1' } } }],
      'edges' => [{ 'id' => 'e', 'source' => 't', 'target' => 'a' }]
    }
  end
  let!(:workflow) { account.automation_workflows.create!(name: 'Perdidos', graph: graph, active: true) }

  describe '.fire' do
    it 'starts the active workflows that listen to the event' do
      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1 }) }
        .to change { workflow.runs.count }.by(1).and have_enqueued_job(Workflows::RunJob)
      expect(workflow.runs.last).to have_attributes(trigger_event: 'crm_deal_lost', pending: [{ 'node_id' => 't' }])
    end

    it 'ignores other events, inactive workflows and other accounts' do
      workflow.update!(active: false)
      create(:account).automation_workflows.create!(name: 'Outra conta', graph: graph, active: true)

      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: {}) }.not_to(change(AutomationWorkflowRun, :count))
      expect { described_class.fire(account: account, event: 'crm_deal_won', context: {}) }.not_to(change(AutomationWorkflowRun, :count))
    end

    it 'does not start a workflow from what the same workflow did' do
      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1 }, performed_by: workflow) }
        .not_to(change { workflow.runs.count })
    end

    it 'stops a chain of workflows that keeps handing the same deal back' do
      other = account.automation_workflows.create!(name: 'Outro', graph: graph)
      described_class::CHAIN_LIMIT.times do
        workflow.runs.create!(account_id: account.id, trigger_event: 'crm_deal_lost', started_at: Time.current, context: { 'deal_id' => 1 })
      end

      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1 }, performed_by: other) }
        .not_to(change { workflow.runs.count })
      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 2 }, performed_by: other) }
        .to change { workflow.runs.count }.by(1)
    end

    it 'stops events that the pipeline automations have chained too deep' do
      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1, 'automation_depth' => Crm::StageAutomationService::MAX_DEPTH }) }
        .not_to(change { workflow.runs.count })
    end

    it 'counts an event from a pipeline automation job against the chain limit' do
      described_class::CHAIN_LIMIT.times do
        workflow.runs.create!(account_id: account.id, trigger_event: 'crm_deal_lost', started_at: Time.current, context: { 'deal_id' => 1 })
      end

      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1, 'automation_depth' => 1 }) }
        .not_to(change { workflow.runs.count })
    end

    it 'does not limit events that people or channels caused' do
      described_class::CHAIN_LIMIT.times do
        workflow.runs.create!(account_id: account.id, trigger_event: 'crm_deal_lost', started_at: Time.current, context: { 'deal_id' => 1 })
      end

      expect { described_class.fire(account: account, event: 'crm_deal_lost', context: { 'deal_id' => 1 }) }.to change { workflow.runs.count }.by(1)
    end
  end

  describe '.start' do
    it 'starts a manual run from every trigger node' do
      expect(described_class.start(workflow, 'manual', { 'deal_id' => 1 }).pending).to eq([{ 'node_id' => 't' }])
    end

    it 'does nothing when the workflow has no trigger for the event' do
      expect(described_class.start(workflow, 'webhook', {})).to be_nil
    end
  end
end
