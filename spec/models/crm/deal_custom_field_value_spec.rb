require 'rails_helper'

RSpec.describe Crm::DealCustomFieldValue do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead') }
  let(:field) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'select', options: %w[Restaurante Clínica]) }
  let(:route) { { 'operator' => 'equals', 'value' => 'Restaurante', 'pipeline_id' => pipeline.id, 'stage_id' => stage.id } }

  def save_value(value)
    record = deal.custom_field_values.find_or_initialize_by(custom_field_id: field.id)
    record.account_id = account.id
    record.typed_value = value
    record.save!
  end

  describe 'field automations' do
    it 'does nothing while the pipeline has none' do
      expect { save_value('Restaurante') }.not_to have_enqueued_job(Crm::FieldAutomationJob)
    end

    context 'when the pipeline has field automations' do
      before { pipeline.update!(field_automations: [{ 'type' => 'route_by_field', 'custom_field_id' => field.id, 'routes' => [route] }]) }

      it 'runs them when a value is filled in' do
        expect { save_value('Restaurante') }.to have_enqueued_job(Crm::FieldAutomationJob).with(deal.id, field.id, 0)
      end

      it 'runs them when the value changes, but not when the same value is saved again' do
        save_value('Restaurante')

        expect { save_value('Restaurante') }.not_to have_enqueued_job(Crm::FieldAutomationJob)
        expect { save_value('Clínica') }.to have_enqueued_job(Crm::FieldAutomationJob)
      end

      it 'hands the automation depth to the follow-up so loops are cut' do
        record = deal.custom_field_values.new(account_id: account.id, custom_field: field, typed_value: 'Clínica')
        record.automation_depth = 3

        expect { record.save! }.to have_enqueued_job(Crm::FieldAutomationJob).with(deal.id, field.id, 3)
      end
    end
  end
end
