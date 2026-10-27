require 'rails_helper'

RSpec.describe Crm::StageAutomationService do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:entry_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let!(:restaurant_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Restaurantes', position: 1) }
  let!(:clinic_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Clínicas', position: 2) }
  let(:contact) { create(:contact, account: account) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: entry_stage, contact: contact, name: 'Lead') }
  let(:segment) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica]) }
  let(:notes) { account.crm_custom_fields.create!(name: 'Observação', key: 'observacao', field_type: 'text') }
  let(:sellers) { create_list(:user, 3, account: account, role: :agent) }

  def move_to(stage_id)
    { 'type' => 'move_stage', 'pipeline_id' => pipeline.id, 'stage_id' => stage_id }
  end

  def route_by_segment
    {
      'type' => 'route_by_field', 'custom_field_id' => segment.id,
      'routes' => [
        { 'operator' => 'equals', 'value' => 'Restaurante', 'pipeline_id' => pipeline.id, 'stage_id' => restaurant_stage.id },
        { 'operator' => 'equals', 'value' => 'Clínica', 'pipeline_id' => pipeline.id, 'stage_id' => clinic_stage.id }
      ]
    }
  end

  def fill(field, value)
    deal.custom_field_values.create!(account: account, custom_field: field, typed_value: value)
  end

  def run(**options)
    described_class.new(deal.reload, **options).perform
  end

  describe 'assign_random' do
    it 'gives the deal to one of the chosen sellers' do
      entry_stage.update!(automations: [{ 'type' => 'assign_random', 'user_ids' => sellers.map(&:id) }])

      run
      expect(sellers.map(&:id)).to include(deal.reload.owner_id)
    end

    it 'spreads deals between all chosen sellers' do
      entry_stage.update!(automations: [{ 'type' => 'assign_random', 'user_ids' => sellers.map(&:id) }])

      owners = Array.new(60) do
        run
        deal.reload.owner_id
      end

      expect(owners.uniq).to match_array(sellers.map(&:id))
    end
  end

  describe 'set_field' do
    it 'fills a custom field of the deal' do
      entry_stage.update!(automations: [{ 'type' => 'set_field', 'custom_field_id' => notes.id, 'value' => 'Veio do Instagram' }])

      run
      expect(deal.custom_field_values.find_by(custom_field_id: notes.id).typed_value).to eq('Veio do Instagram')
    end

    it 'overwrites the value the field already had' do
      fill(notes, 'antigo')
      entry_stage.update!(automations: [{ 'type' => 'set_field', 'custom_field_id' => notes.id, 'value' => 'novo' }])

      run
      expect(deal.custom_field_values.where(custom_field_id: notes.id).map(&:typed_value)).to eq(['novo'])
    end
  end

  describe 'route_by_field' do
    before { entry_stage.update!(automations: [route_by_segment]) }

    it 'sends the deal to the stage that matches the field value' do
      fill(segment, 'Clínica')

      run
      expect(deal.reload.pipeline_stage_id).to eq(clinic_stage.id)
    end

    it 'keeps the deal where it is when no rule matches' do
      run
      expect(deal.reload.pipeline_stage_id).to eq(entry_stage.id)
    end

    it 'uses the fallback when no rule matches' do
      entry_stage.update!(automations: [route_by_segment.merge('fallback' => { 'pipeline_id' => pipeline.id, 'stage_id' => clinic_stage.id })])

      run
      expect(deal.reload.pipeline_stage_id).to eq(clinic_stage.id)
    end

    it 'takes the first rule that matches' do
      first_match = { 'operator' => 'contains', 'value' => 'a', 'pipeline_id' => pipeline.id, 'stage_id' => restaurant_stage.id }
      entry_stage.update!(automations: [route_by_segment.merge('routes' => [first_match] + route_by_segment['routes'])])
      fill(segment, 'Clínica')

      run
      expect(deal.reload.pipeline_stage_id).to eq(restaurant_stage.id)
    end
  end

  describe 'conditions' do
    let(:condition) { { 'custom_field_id' => segment.id, 'operator' => 'equals', 'value' => 'Restaurante' } }

    it 'runs the action only when the field matches' do
      entry_stage.update!(automations: [move_to(clinic_stage.id).merge('condition' => condition)])

      run
      expect(deal.reload.pipeline_stage_id).to eq(entry_stage.id)

      fill(segment, 'Restaurante')
      run
      expect(deal.reload.pipeline_stage_id).to eq(clinic_stage.id)
    end

    it 'records skipped actions in the deal history' do
      entry_stage.update!(automations: [move_to(clinic_stage.id).merge('condition' => condition)])

      run
      event = deal.events.find_by(event_type: 'automation_run')
      expect(event.metadata['actions']).to eq([{ 'type' => 'move_stage', 'ok' => true, 'skipped' => true }])
    end
  end

  describe 'field trigger' do
    let(:other_condition) { { 'custom_field_id' => notes.id, 'operator' => 'filled' } }

    before do
      pipeline.update!(field_automations: [route_by_segment, move_to(clinic_stage.id).merge('condition' => other_condition)])
    end

    it 'only runs the actions that watch the field that changed' do
      fill(segment, 'Restaurante')

      run(trigger: 'field', field_id: segment.id)
      expect(deal.reload.pipeline_stage_id).to eq(restaurant_stage.id)
    end

    it 'ignores changes to fields no action watches' do
      fill(notes, 'qualquer coisa')

      run(trigger: 'field', field_id: segment.id)
      expect(deal.reload.pipeline_stage_id).to eq(entry_stage.id)
    end

    it 'stops automations that keep writing each other' do
      pipeline.update!(field_automations: [
                         { 'type' => 'set_field', 'custom_field_id' => notes.id, 'value' => 'x',
                           'condition' => { 'custom_field_id' => notes.id, 'operator' => 'not_equals', 'value' => 'x' } }
                       ])
      fill(notes, 'y')

      expect { run(trigger: 'field', field_id: notes.id, depth: described_class::MAX_DEPTH) }
        .not_to(change { deal.custom_field_values.find_by(custom_field_id: notes.id).value })
    end
  end

  describe 'webhook event name' do
    it 'has one for the field trigger' do
      expect(described_class::WEBHOOK_EVENTS).to include('field' => 'crm_deal_field_changed')
    end
  end
end
