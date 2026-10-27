require 'rails_helper'

RSpec.describe Crm::Segment do
  let(:account) { create(:account) }

  it 'needs a name that is unique in the account, ignoring case and spaces around it' do
    account.crm_segments.create!(name: ' Restaurantes ')

    expect(account.crm_segments.create!(name: 'Clínicas')).to be_persisted
    expect(account.crm_segments.build(name: 'restaurantes')).not_to be_valid
    expect(create(:account).crm_segments.build(name: 'Restaurantes')).to be_valid
    expect(account.crm_segments.build(name: ' ')).not_to be_valid
  end

  it 'saves the name without the surrounding spaces' do
    expect(account.crm_segments.create!(name: '  Padarias ').name).to eq('Padarias')
  end

  it 'only accepts hex colors' do
    expect(account.crm_segments.build(name: 'A', color: '#1f93ff')).to be_valid
    expect(account.crm_segments.build(name: 'B', color: 'azul')).not_to be_valid
    expect(account.crm_segments.build(name: 'C', color: '')).to be_valid
  end

  it 'is kept by deals of the same account only' do
    pipeline = account.crm_pipelines.create!(name: 'Comercial')
    stage = account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0)
    contact = create(:contact, account: account)
    other_segment = create(:account).crm_segments.create!(name: 'Outra conta')

    deal = account.crm_deals.build(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead', segment: other_segment)

    expect(deal).not_to be_valid
    expect(deal.errors[:segment]).to be_present
  end
end
