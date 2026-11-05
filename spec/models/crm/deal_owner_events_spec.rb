require 'rails_helper'

RSpec.describe Crm::Deal, '#owner_id' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:other_seller) { create(:user, account: account, role: :agent) }
  let(:dispatcher) { Rails.configuration.dispatcher }
  let!(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead') }

  before { allow(dispatcher).to receive(:dispatch).and_call_original }

  def owner_events
    have_received(:dispatch).with(Events::Types::CRM_DEAL_OWNER_CHANGED, anything, hash_including(deal: deal))
  end

  it 'announces who the owner was and who it is now' do
    deal.update!(owner: seller)

    expect(dispatcher).to owner_events.once
    expect(dispatcher).to have_received(:dispatch).with(
      Events::Types::CRM_DEAL_OWNER_CHANGED, anything, hash_including(changed_attributes: hash_including('owner_id' => [nil, seller.id]))
    )
  end

  it 'announces a change from one owner to another and the removal of the owner' do
    deal.update!(owner: seller)
    deal.update!(owner: other_seller)
    deal.update!(owner: nil)

    expect(dispatcher).to owner_events.exactly(3).times
  end

  it 'does not announce an owner change when something else changes' do
    deal.update!(name: 'Outro nome', value: 1000)

    expect(dispatcher).not_to owner_events
  end

  it 'does not announce an owner change when the same owner is saved again' do
    deal.update!(owner: seller)
    deal.update!(owner: seller, name: 'Renomeado')

    expect(dispatcher).to owner_events.once
  end

  it 'does not announce an owner change when a deal is created with an owner' do
    account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Novo lead', owner: seller)

    expect(dispatcher).not_to have_received(:dispatch).with(Events::Types::CRM_DEAL_OWNER_CHANGED, anything, anything)
  end
end
