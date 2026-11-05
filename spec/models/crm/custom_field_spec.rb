require 'rails_helper'

RSpec.describe Crm::CustomField do
  describe 'of type user' do
    let(:account) { create(:account) }
    let(:seller) { create(:user, account: account, role: :agent) }
    let(:field) { account.crm_custom_fields.create!(name: 'Vendedor', key: 'vendedor', field_type: 'user') }
    let(:contact) { create(:contact, account: account) }
    let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
    let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
    let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }

    def value_of(input)
      deal.custom_field_values.build(account: account, custom_field: field, typed_value: input)
    end

    it 'does not need options' do
      expect(field).to be_valid
    end

    it 'accepts the id of someone from the account' do
      expect(value_of(seller.id)).to be_valid
    end

    it 'refuses someone from another account, an unknown id and anything that is not an id' do
      stranger = create(:user, account: create(:account), role: :agent)

      expect(value_of(stranger.id)).not_to be_valid
      expect(value_of(0)).not_to be_valid
      expect(value_of('Ana')).not_to be_valid
    end

    it 'reads the value back as the id' do
      record = deal.custom_field_values.create!(account: account, custom_field: field, typed_value: seller.id)

      expect(record.reload.typed_value).to eq(seller.id)
    end

    it 'works in the conditions of the automations, which compare the id' do
      deal.custom_field_values.create!(account: account, custom_field: field, typed_value: seller.id)

      expect(Crm::FieldCondition.met?(deal, field.id, 'equals', seller.id.to_s)).to be(true)
      expect(Crm::FieldCondition.met?(deal, field.id, 'equals', (seller.id + 1).to_s)).to be(false)
      expect(Crm::FieldCondition.met?(deal, field.id, 'filled', nil)).to be(true)
    end
  end
end
