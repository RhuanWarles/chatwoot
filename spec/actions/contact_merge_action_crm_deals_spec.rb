require 'rails_helper'

RSpec.describe ContactMergeAction, 'CRM cards' do
  let(:account) { create(:account) }
  let(:base_contact) { create(:contact, account: account) }
  let(:mergee_contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let!(:mergee_deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: mergee_contact, name: 'Do mergee') }

  it 'keeps the cards of the contact that is merged away instead of destroying them' do
    mergee_deal.activities.create!(account_id: account.id, contact_id: mergee_contact.id, activity_type: 'task', title: 'Ligar', due_at: 1.day.from_now)

    described_class.new(account: account, base_contact: base_contact, mergee_contact: mergee_contact).perform

    expect(mergee_deal.reload.contact_id).to eq(base_contact.id)
    expect(mergee_deal.activities.first.contact_id).to eq(base_contact.id)
  end
end
