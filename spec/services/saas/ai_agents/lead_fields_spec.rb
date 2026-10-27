require 'rails_helper'

RSpec.describe Saas::AiAgents::LeadFields do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { account.saas_ai_agents.build }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: conversation.contact, name: 'Lead') }
  let!(:segment) do
    account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica])
  end
  let!(:interests) do
    account.crm_custom_fields.create!(name: 'Interesses', key: 'interesses', field_type: 'multiselect', options: %w[Site App CRM])
  end

  describe 'as a plain helper' do
    let(:fields) { described_class.new(account, enabled: true) }

    it 'is empty when the agent does not control the lead' do
      expect(described_class.new(account, enabled: false)).not_to be_any
    end

    it 'ignores inactive custom fields' do
      segment.update!(active: false)

      expect(fields.properties['field']['enum']).to eq(['interesses'])
    end

    it 'tells the model how to fill each field' do
      expect(fields.description).to include('segmento (Segmento): uma destas opções: Restaurante, Clínica')
      expect(fields.description).to include('separadas por |')
    end

    it 'fills a select field and writes it to the deal history' do
      expect(fields.fill(deal, 'segmento', 'Clínica')).to eq('Campo Segmento registrado.')

      expect(deal.custom_field_values.find_by(custom_field_id: segment.id).typed_value).to eq('Clínica')
      event = deal.events.find_by(event_type: 'custom_field_changed')
      expect(event.metadata).to include('field_key' => 'segmento', 'to' => 'Clínica')
    end

    it 'splits several options of a multiselect field' do
      fields.fill(deal, 'interesses', 'Site | CRM')

      expect(deal.custom_field_values.find_by(custom_field_id: interests.id).typed_value).to eq(%w[Site CRM])
    end

    it 'refuses a value outside the options so the model can try again' do
      expect { fields.fill(deal, 'segmento', 'Padaria') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'through the built-in tools' do
    let(:tools) { Saas::AiAgents::BuiltinTools.new(agent: agent, conversation: conversation) }

    before do
      agent.configure!({ name: 'IA', system_prompt: 'Ajude', provider: 'openai', model: 'test-model', active: true,
                         crm_stage_automation_enabled: true, crm_pipeline_id: pipeline.id }, selected_inboxes: [inbox])
    end

    it 'offers the tool only while the AI controls the lead' do
      expect(tools.definitions.map { |definition| definition.dig(:function, :name) }).to include(Saas::AiAgents::BuiltinTools::UPDATE_FIELD)

      agent.update!(crm_stage_automation_enabled: false)
      fresh_tools = Saas::AiAgents::BuiltinTools.new(agent: agent, conversation: conversation)

      expect(fresh_tools.definitions.map { |definition| definition.dig(:function, :name) })
        .not_to include(Saas::AiAgents::BuiltinTools::UPDATE_FIELD)
    end

    it 'fills the field of the open lead' do
      deal

      result = tools.call(Saas::AiAgents::BuiltinTools::UPDATE_FIELD, { 'field' => 'segmento', 'value' => 'Restaurante' })

      expect(result).to include('success' => true)
      expect(deal.custom_field_values.find_by(custom_field_id: segment.id).typed_value).to eq('Restaurante')
    end

    it 'creates the lead when the customer has none yet' do
      expect { tools.call(Saas::AiAgents::BuiltinTools::UPDATE_FIELD, { 'field' => 'segmento', 'value' => 'Clínica' }) }
        .to change(account.crm_deals, :count).by(1)
    end

    it 'does not create a lead for a field that does not exist' do
      result = nil

      expect { result = tools.call(Saas::AiAgents::BuiltinTools::UPDATE_FIELD, { 'field' => 'cpf', 'value' => '1' }) }
        .not_to change(account.crm_deals, :count)
      expect(result['result']).to eq('Campo inválido.')
    end

    it 'reports invalid values back to the model instead of raising' do
      deal

      result = tools.call(Saas::AiAgents::BuiltinTools::UPDATE_FIELD, { 'field' => 'segmento', 'value' => 'Padaria' })

      expect(result).to include('success' => false)
    end
  end
end
