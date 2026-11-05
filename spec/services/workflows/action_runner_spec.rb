require 'rails_helper'

RSpec.describe Workflows::ActionRunner do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:contact) { create(:contact, account: account) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }
  let(:workflow) { account.automation_workflows.create!(name: 'Teste', graph: { 'nodes' => [], 'edges' => [] }) }
  let(:run_context) { { 'deal_id' => deal.id, 'contact_id' => contact.id } }
  let(:run) { workflow.runs.create!(account_id: account.id, trigger_event: 'manual', started_at: Time.current, context: run_context) }
  let(:runner) { described_class.new(Workflows::Context.new(run), workflow) }

  describe 'deal custom fields' do
    let!(:field) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica]) }

    it 'writes the value of an active field' do
      runner.perform('set_deal_field', { 'fields' => [{ 'key' => 'segmento', 'value' => 'Clínica' }] })

      expect(deal.custom_field_values.find_by(custom_field: field).value).to eq('Clínica')
    end

    it 'fails for a field that does not exist or is inactive' do
      field.update!(active: false)

      expect { runner.perform('set_deal_field', { 'fields' => [{ 'key' => 'segmento', 'value' => 'Clínica' }] }) }
        .to raise_error(Workflows::ActionRunner::MissingRecord)
    end
  end

  describe 'contact custom fields' do
    it 'writes the value of a defined attribute and refuses an unknown one' do
      create(:custom_attribute_definition, account: account, attribute_model: :contact_attribute, attribute_key: 'plano')

      runner.perform('set_contact_field', { 'fields' => [{ 'key' => 'plano', 'value' => 'pro' }] })

      expect(contact.reload.custom_attributes).to include('plano' => 'pro')
      expect { runner.perform('set_contact_field', { 'fields' => [{ 'key' => 'nope', 'value' => 'x' }] }) }
        .to raise_error(Workflows::ActionRunner::MissingRecord)
    end
  end

  describe 'filling the user field after the draw' do
    let!(:seller_field) { account.crm_custom_fields.create!(name: 'Vendedor', key: 'vendedor', field_type: 'user') }
    let(:sellers) { create_list(:user, 2, account: account, role: :agent) }

    def filled
      deal.reload.custom_field_values.find_by(custom_field: seller_field)&.typed_value
    end

    it 'writes the person of a random assignment in the field' do
      runner.perform('assign_deal_owner', { 'mode' => 'random', 'user_ids' => sellers.map(&:id), 'custom_field_key' => 'vendedor' })

      expect(filled).to eq(deal.reload.owner_id)
      expect(sellers.map(&:id)).to include(filled)
    end

    it 'writes the person of a fixed assignment too' do
      runner.perform('assign_deal_owner', { 'mode' => 'user', 'user_id' => sellers.first.id, 'custom_field_key' => 'vendedor' })

      expect(filled).to eq(sellers.first.id)
    end

    it 'does not touch any field when none was chosen' do
      runner.perform('assign_deal_owner', { 'mode' => 'user', 'user_id' => sellers.first.id })

      expect(filled).to be_nil
    end

    it 'refuses a field that is not of type user and one that does not exist' do
      account.crm_custom_fields.create!(name: 'Texto', key: 'texto', field_type: 'text')

      expect { runner.perform('assign_deal_owner', { 'mode' => 'user', 'user_id' => sellers.first.id, 'custom_field_key' => 'texto' }) }
        .to raise_error(ArgumentError, /not a user field/)
      expect { runner.perform('assign_deal_owner', { 'mode' => 'user', 'user_id' => sellers.first.id, 'custom_field_key' => 'nope' }) }
        .to raise_error(Workflows::ActionRunner::MissingRecord)
    end
  end

  describe 'distribute_deal' do
    let!(:seller_field) { account.crm_custom_fields.create!(name: 'Vendedor', key: 'vendedor', field_type: 'user') }
    let(:ana) { create(:user, account: account, role: :agent) }
    let(:bia) { create(:user, account: account, role: :agent) }
    let(:context) { Workflows::Context.new(run) }

    def half_and_half
      [{ 'user_id' => ana.id, 'percentage' => 50 }, { 'user_id' => bia.id, 'percentage' => 50 }]
    end

    def distributor
      described_class.new(context, workflow)
    end

    before { context.node_id = 'rodizio' }

    it 'makes the next person the owner of the card and writes them in the field' do
      params = { 'assignees' => half_and_half, 'custom_field_key' => 'vendedor', 'assign_conversation' => false }

      output = distributor.perform('distribute_deal', params)

      expect(output).to include('deal_id' => deal.id, 'owner_id' => ana.id)
      expect(deal.reload.owner_id).to eq(ana.id)
      expect(deal.custom_field_values.find_by(custom_field: seller_field).typed_value).to eq(ana.id)
    end

    it 'follows the percentages from one lead to the next' do
      owners = Array.new(4) do
        other = account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Outro')
        another = Workflows::Context.new(workflow.runs.create!(account_id: account.id, trigger_event: 'manual', started_at: Time.current,
                                                               context: { 'deal_id' => other.id, 'contact_id' => contact.id }))
        another.node_id = 'rodizio'
        described_class.new(another, workflow).perform('distribute_deal', { 'assignees' => half_and_half, 'assign_conversation' => false })
        other.reload.owner_id
      end

      expect(owners).to eq([ana.id, bia.id, ana.id, bia.id])
    end

    it 'hands the conversation of the lead to the same person' do
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: ana, inbox: conversation.inbox)
      conversation_context = Workflows::Context.new(workflow.runs.create!(account_id: account.id, trigger_event: 'manual', started_at: Time.current,
                                                                          context: run_context.merge('conversation_id' => conversation.id)))
      conversation_context.node_id = 'rodizio'

      output = described_class.new(conversation_context, workflow).perform('distribute_deal', { 'assignees' => half_and_half })

      expect(conversation.reload.assignee_id).to eq(ana.id)
      expect(output).to include('owner_id' => ana.id, 'conversation_id' => conversation.id)
    end

    it 'reports a person who cannot take the conversation' do
      conversation = create(:conversation, account: account, contact: contact)
      conversation_context = Workflows::Context.new(workflow.runs.create!(account_id: account.id, trigger_event: 'manual', started_at: Time.current,
                                                                          context: run_context.merge('conversation_id' => conversation.id)))
      conversation_context.node_id = 'rodizio'

      expect { described_class.new(conversation_context, workflow).perform('distribute_deal', { 'assignees' => half_and_half }) }
        .to raise_error(ArgumentError, /could not assign/)
    end

    it 'still sets the owner when the lead has no conversation' do
      output = distributor.perform('distribute_deal', { 'assignees' => half_and_half })

      expect(deal.reload.owner_id).to eq(ana.id)
      expect(output['conversation_id']).to be_nil
    end

    it 'refuses percentages that do not add up and people from another account' do
      stranger = create(:user, account: create(:account), role: :agent)

      expect { distributor.perform('distribute_deal', { 'assignees' => [{ 'user_id' => ana.id, 'percentage' => 40 }] }) }
        .to raise_error(ArgumentError, /add up to 100/)
      expect { distributor.perform('distribute_deal', { 'assignees' => [{ 'user_id' => stranger.id, 'percentage' => 100 }] }) }
        .to raise_error(ArgumentError, /does not belong/)
    end
  end

  describe 'deal actions' do
    it 'sets the status with a reason' do
      reason = account.crm_lost_reasons.create!(name: 'Preço')

      runner.perform('set_deal_status', { 'status' => 'lost', 'lost_reason_id' => reason.id, 'lost_note' => 'Caro' })

      expect(deal.reload).to have_attributes(status: 'lost', lost_reason_id: reason.id, lost_note: 'Caro')
    end

    it 'creates a deal for the contact and makes it the deal of the run' do
      context = Workflows::Context.new(run)

      described_class.new(context, workflow).perform('create_deal', { 'pipeline_id' => pipeline.id, 'pipeline_stage_id' => stage.id, 'name' => 'Novo' })

      expect(context.state['deal_id']).to eq(account.crm_deals.find_by(name: 'Novo').id)
    end

    it 'passes the depth of the event on to the events of the changes it makes' do
      run_context['automation_depth'] = 2
      deal
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      runner.perform('update_deal', { 'name' => 'Renomeado' })

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(Events::Types::CRM_DEAL_UPDATED, anything,
                                                                              hash_including(automation_depth: 3))
    end
  end

  describe 'conversation actions' do
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:conversation) { create(:conversation, account: account, contact: contact) }
    let(:run_context) { { 'conversation_id' => conversation.id, 'contact_id' => contact.id } }

    it 'reports an agent that cannot be assigned instead of doing nothing' do
      expect { runner.perform('assign_agent', { 'agent_id' => agent.id }) }.to raise_error(ArgumentError, /could not assign/)
    end

  end

  it 'fails a conversation action when the run has no conversation' do
    expect { runner.perform('send_message', { 'content' => 'Oi' }) }.to raise_error(Workflows::ActionRunner::MissingRecord)
  end

  describe 'http_request' do
    let(:result) { instance_double(SafeFetch::Result, tempfile: StringIO.new('{"ok":true}')) }

    it 'sends the request through SafeFetch with the configured headers and body' do
      allow(SafeFetch).to receive(:fetch).and_yield(result)

      output = runner.perform('http_request', { 'method' => 'POST', 'url' => 'https://example.com/hook', 'body' => '{"a":1}',
                                                'headers' => [{ 'key' => 'X-Token', 'value' => 'abc' }] })

      expect(SafeFetch).to have_received(:fetch).with(
        'https://example.com/hook', hash_including(method: 'post', body: '{"a":1}',
                                                   headers: { 'X-Token' => 'abc', 'Content-Type' => 'application/json' })
      )
      expect(output).to include('method' => 'POST', 'response' => '{"ok":true}')
    end

    it 'keeps a content type the user chose' do
      allow(SafeFetch).to receive(:fetch)

      runner.perform('http_request', { 'url' => 'https://example.com', 'body' => 'a=1', 'headers' => [{ 'key' => 'content-type', 'value' => 'text/plain' }] })

      expect(SafeFetch).to have_received(:fetch).with('https://example.com', hash_including(headers: { 'content-type' => 'text/plain' }))
    end

    it 'treats a response that is too large as delivered' do
      allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::FileTooLargeError)

      output = runner.perform('http_request', { 'method' => 'GET', 'url' => 'https://example.com' })

      expect(output).to include('response' => Workflows::Actions::IntegrationActions::TOO_LARGE_PREVIEW)
    end

    it 'does not turn the failure of the other system into a success' do
      allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::HttpError, '500 Internal Server Error')

      expect { runner.perform('http_request', { 'url' => 'https://example.com' }) }.to raise_error(SafeFetch::HttpError)
    end
  end

  it 'refuses an unknown action' do
    expect { runner.perform('destroy_everything', {}) }.to raise_error(ArgumentError, /unknown action/)
  end
end
