require 'rails_helper'

RSpec.describe Crm::Deal do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:contact) { create(:contact, account: account) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }
  let!(:reason) { account.crm_lost_reasons.create!(name: 'Sem orçamento') }

  describe 'lost reason' do
    it 'is required from people when the account has active reasons' do
      deal.require_lost_reason = true

      expect(deal.update(status: 'lost')).to be(false)
      expect(deal.errors[:lost_reason]).to be_present
    end

    it 'is not required when every reason is inactive' do
      reason.update!(active: false)
      deal.require_lost_reason = true

      expect(deal.update(status: 'lost')).to be(true)
    end

    it 'is not required from automations' do
      expect(deal.update(status: 'lost')).to be(true)
    end

    it 'must belong to the same account' do
      other = create(:account).crm_lost_reasons.create!(name: 'De outra conta')

      expect(deal.update(status: 'lost', lost_reason_id: other.id)).to be(false)
    end

    it 'is written on the status timeline event' do
      deal.update!(status: 'lost', lost_reason_id: reason.id, lost_note: 'Achou caro')

      event = deal.events.find_by(event_type: 'status_changed')
      expect(event.metadata).to include('to' => 'lost', 'lost_reason_id' => reason.id, 'lost_reason' => 'Sem orçamento', 'lost_note' => 'Achou caro')
    end

    it 'is cleared when the deal leaves the lost status' do
      deal.update!(status: 'lost', lost_reason_id: reason.id, lost_note: 'Achou caro')

      deal.update!(status: 'open')

      expect(deal.reload).to have_attributes(lost_reason_id: nil, lost_note: nil)
    end
  end
end
