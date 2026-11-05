require 'rails_helper'

RSpec.describe Crm::LostReasonField do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let!(:recovery_stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Recuperar preço', position: 1) }
  let!(:price) { account.crm_lost_reasons.create!(name: 'Preço') }
  let!(:silence) { account.crm_lost_reasons.create!(name: 'Sem resposta') }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }

  def field
    described_class.for(account)
  end

  # The lost automations of the pipeline send the card to the recovery stage when the reason is the price.
  def route_lost_by_reason
    route = { 'operator' => 'equals', 'value' => 'Preço', 'pipeline_id' => pipeline.id, 'stage_id' => recovery_stage.id }
    pipeline.update!(lost_automations: [{ 'type' => 'route_by_field', 'custom_field_id' => field.id, 'routes' => [route] }])
  end

  def held_by(record)
    record.reload.custom_field_values.find_by(custom_field: field)&.value
  end

  describe '.sync!' do
    it 'creates nothing while the account has no reason' do
      empty = create(:account)

      expect(described_class.sync!(empty)).to be_nil
      expect(empty.crm_custom_fields).to be_empty
    end

    it 'creates the field with the reasons as options, once' do
      described_class.sync!(account)
      described_class.sync!(account)

      expect(account.crm_custom_fields.where(system_key: Crm::CustomField::LOST_REASON_KEY).count).to eq(1)
      expect(field).to have_attributes(name: 'Motivo da perda', key: 'motivo_da_perda', field_type: 'select', options: ['Preço', 'Sem resposta'])
      expect(field).to be_system
    end

    it 'follows the reasons that are created later and keeps what deals still hold' do
      described_class.sync!(account)
      deal.update!(status: 'lost', lost_reason: price)
      price.destroy!
      account.crm_lost_reasons.create!(name: 'Concorrente')

      described_class.sync!(account)

      expect(field.options).to contain_exactly('Concorrente', 'Preço', 'Sem resposta')
    end

    it 'does not take a key that a person already used' do
      account.crm_custom_fields.create!(name: 'Outro', key: 'motivo_da_perda', field_type: 'text')

      expect(described_class.sync!(account).key).to start_with('motivo_da_perda_')
    end

    it 'fills the deals that were lost before the field existed, without starting automations' do
      lost = account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Antigo', status: 'lost',
                                       lost_reason: silence)
      dispatcher = Rails.configuration.dispatcher
      allow(dispatcher).to receive(:dispatch).and_call_original

      described_class.sync!(account)

      expect(held_by(lost)).to eq('Sem resposta')
      expect(dispatcher).not_to have_received(:dispatch).with(Events::Types::CRM_DEAL_FIELD_CHANGED, anything, anything)
    end
  end

  describe 'an account whose reasons existed before the field' do
    it 'asks for the field when a deal is lost, and fills it with the sync' do
      expect { deal.update!(status: 'lost', lost_reason: price) }.to have_enqueued_job(Crm::LostReasonFieldSyncJob).with(account.id)

      Crm::LostReasonFieldSyncJob.perform_now(account.id)

      expect(held_by(deal)).to eq('Preço')
    end

    it 'does not ask for anything when the account has no reason' do
      empty = create(:account)
      empty_pipeline = empty.crm_pipelines.create!(name: 'Comercial')
      empty_stage = empty.crm_pipeline_stages.create!(pipeline: empty_pipeline, name: 'Novo', position: 0)
      lost = empty.crm_deals.create!(pipeline: empty_pipeline, pipeline_stage: empty_stage, contact: create(:contact, account: empty), name: 'Lead')

      expect { lost.update!(status: 'lost') }.not_to have_enqueued_job(Crm::LostReasonFieldSyncJob)
    end
  end

  describe 'when a deal is lost' do
    before { described_class.sync!(account) }

    it 'writes the reason in the field' do
      deal.update!(status: 'lost', lost_reason: price)

      expect(held_by(deal)).to eq('Preço')
    end

    it 'follows a change of reason and is cleared when the deal is reopened' do
      deal.update!(status: 'lost', lost_reason: price)
      deal.update!(lost_reason: silence)
      expect(held_by(deal)).to eq('Sem resposta')

      deal.update!(status: 'open')
      expect(held_by(deal)).to be_nil
    end

    it 'does not stop a person from losing a deal for a reason created a moment ago' do
      fresh = account.crm_lost_reasons.create!(name: 'Mudou de ideia')

      deal.update!(status: 'lost', lost_reason: fresh)

      expect(held_by(deal)).to eq('Mudou de ideia')
      expect(field.reload.options).to include('Mudou de ideia')
    end

    it 'writes nothing for a deal lost without a reason' do
      deal.update!(status: 'lost')

      expect(held_by(deal)).to be_nil
    end

    it 'starts the automations that watch the field' do
      watcher = { 'type' => 'add_label', 'label' => 'perdido', 'condition' => { 'custom_field_id' => field.id, 'operator' => 'filled' } }
      pipeline.update!(field_automations: [watcher])

      expect { deal.update!(status: 'lost', lost_reason: price) }.to have_enqueued_job(Crm::FieldAutomationJob).with(deal.id, field.id, 0)
    end
  end

  describe 'sending the card somewhere according to the reason' do
    before { described_class.sync!(account) }

    it 'lets the lost automations of the pipeline route by the reason' do
      route_lost_by_reason
      deal.update!(status: 'lost', lost_reason: price)

      Crm::StageAutomationService.new(deal.reload, trigger: 'lost').perform

      expect(deal.reload.pipeline_stage_id).to eq(recovery_stage.id)
    end

    it 'leaves the card where it is for a reason without a route' do
      route_lost_by_reason
      deal.update!(status: 'lost', lost_reason: silence)

      Crm::StageAutomationService.new(deal.reload, trigger: 'lost').perform

      expect(deal.reload.pipeline_stage_id).to eq(stage.id)
    end
  end

  describe 'the reasons' do
    before { described_class.sync!(account) }

    it 'ask for a sync when they change' do
      expect { account.crm_lost_reasons.create!(name: 'Novo') }.to have_enqueued_job(Crm::LostReasonFieldSyncJob).with(account.id)
    end

    it 'send the old and the new name when one is renamed' do
      expect { price.update!(name: 'Preço alto') }.to have_enqueued_job(Crm::LostReasonFieldSyncJob).with(account.id, 'Preço', 'Preço alto')
    end

    it 'rename what the deals hold' do
      deal.update!(status: 'lost', lost_reason: price)
      price.update!(name: 'Preço alto')

      Crm::LostReasonFieldSyncJob.perform_now(account.id, 'Preço', 'Preço alto')

      expect(held_by(deal)).to eq('Preço alto')
      expect(field.reload.options).to include('Preço alto')
    end
  end
end
