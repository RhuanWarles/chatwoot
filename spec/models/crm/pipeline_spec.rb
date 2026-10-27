require 'rails_helper'

RSpec.describe Crm::Pipeline do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:segment) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica]) }
  let(:sellers) { create_list(:user, 2, account: account, role: :agent) }

  def valid_with?(automations)
    pipeline.assign_attributes(field_automations: automations)
    pipeline.valid?
  end

  describe 'automation limit' do
    it 'accepts up to 50 actions' do
      one_seller = { 'type' => 'assign_owner', 'user_id' => sellers.first.id }

      expect(valid_with?(Array.new(50) { one_seller })).to be(true)
      expect(valid_with?(Array.new(51) { one_seller })).to be(false)
    end
  end

  describe 'assign_random' do
    it 'needs at least one seller of the account' do
      expect(valid_with?([{ 'type' => 'assign_random', 'user_ids' => sellers.map(&:id) }])).to be(true)
      expect(valid_with?([{ 'type' => 'assign_random', 'user_ids' => [] }])).to be(false)
      expect(valid_with?([{ 'type' => 'assign_random', 'user_ids' => [create(:user).id] }])).to be(false)
      expect(valid_with?([{ 'type' => 'assign_random', 'user_ids' => [sellers.first.id, sellers.first.id] }])).to be(false)
    end
  end

  describe 'set_field' do
    it 'needs a value the field accepts' do
      expect(valid_with?([{ 'type' => 'set_field', 'custom_field_id' => segment.id, 'value' => 'Clínica' }])).to be(true)
      expect(valid_with?([{ 'type' => 'set_field', 'custom_field_id' => segment.id, 'value' => 'Padaria' }])).to be(false)
      expect(valid_with?([{ 'type' => 'set_field', 'custom_field_id' => segment.id, 'value' => '' }])).to be(false)
    end

    it 'does not write inactive fields' do
      segment.update!(active: false)

      expect(valid_with?([{ 'type' => 'set_field', 'custom_field_id' => segment.id, 'value' => 'Clínica' }])).to be(false)
    end
  end

  describe 'route_by_field' do
    let(:route) { { 'operator' => 'equals', 'value' => 'Restaurante', 'pipeline_id' => pipeline.id, 'stage_id' => stage.id } }
    let(:action) { { 'type' => 'route_by_field', 'custom_field_id' => segment.id, 'routes' => [route] } }

    it 'accepts routes to stages of the account, with an optional fallback' do
      expect(valid_with?([action])).to be(true)
      expect(valid_with?([action.merge('fallback' => { 'pipeline_id' => pipeline.id, 'stage_id' => stage.id })])).to be(true)
    end

    it 'rejects missing routes, unknown stages and unknown operators' do
      expect(valid_with?([action.merge('routes' => [])])).to be(false)
      expect(valid_with?([action.merge('routes' => [route.merge('stage_id' => 0)])])).to be(false)
      expect(valid_with?([action.merge('routes' => [route.merge('operator' => 'between')])])).to be(false)
      expect(valid_with?([action.merge('fallback' => { 'pipeline_id' => pipeline.id, 'stage_id' => 0 })])).to be(false)
    end
  end

  describe 'conditions' do
    let(:condition) { { 'custom_field_id' => segment.id, 'operator' => 'equals', 'value' => 'Restaurante' } }

    it 'can be attached to any action' do
      expect(valid_with?([{ 'type' => 'add_label', 'label' => 'vip', 'condition' => condition }])).to be(true)
    end

    it 'must point to a field of the account with a known operator' do
      expect(valid_with?([{ 'type' => 'add_label', 'label' => 'vip', 'condition' => condition.merge('custom_field_id' => 0) }])).to be(false)
      expect(valid_with?([{ 'type' => 'add_label', 'label' => 'vip', 'condition' => condition.merge('operator' => 'x') }])).to be(false)
      expect(valid_with?([{ 'type' => 'add_label', 'label' => 'vip', 'condition' => condition.merge('extra' => 1) }])).to be(false)
    end
  end
end
