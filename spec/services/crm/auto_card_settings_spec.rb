require 'rails_helper'

RSpec.describe Crm::AutoCardSettings do
  let(:account) { create(:account) }
  let(:settings) { described_class.new(account) }
  let!(:old_pipeline) { account.crm_pipelines.create!(name: 'Antigo') }
  let!(:old_first_stage) { account.crm_pipeline_stages.create!(pipeline: old_pipeline, name: 'Entrada', position: 0) }
  let!(:old_second_stage) { account.crm_pipeline_stages.create!(pipeline: old_pipeline, name: 'Contato', position: 1) }
  let!(:new_pipeline) { account.crm_pipelines.create!(name: 'Novo') }
  let!(:new_stage) { account.crm_pipeline_stages.create!(pipeline: new_pipeline, name: 'Lead', position: 0) }

  it 'is on by default and aims at the oldest pipeline that has stages' do
    expect(settings.enabled?).to be(true)
    expect(settings.target).to eq([old_pipeline, old_first_stage])
  end

  it 'skips pipelines that are inactive or have no stages' do
    old_pipeline.update!(active: false)
    account.crm_pipelines.create!(name: 'Vazio')

    expect(settings.target).to eq([new_pipeline, new_stage])
  end

  it 'answers nothing when the account has no usable pipeline' do
    account.crm_pipelines.each { |pipeline| pipeline.update!(active: false) }

    expect(settings.target).to be_nil
  end

  it 'uses the chosen pipeline and stage' do
    settings.update!(enabled: true, pipeline_id: old_pipeline.id, stage_id: old_second_stage.id)

    expect(described_class.new(account.reload).target).to eq([old_pipeline, old_second_stage])
  end

  it 'lets the pipeline of the AI agent win' do
    settings.update!(enabled: true, pipeline_id: old_pipeline.id, stage_id: nil)

    expect(settings.target(preferred_pipeline_id: new_pipeline.id)).to eq([new_pipeline, new_stage])
  end

  it 'refuses a stage of another pipeline and a pipeline of another account' do
    expect { settings.update!(enabled: true, pipeline_id: old_pipeline.id, stage_id: new_stage.id) }.to raise_error(described_class::Invalid)

    other = create(:account).crm_pipelines.create!(name: 'De outra conta')
    expect { settings.update!(enabled: true, pipeline_id: other.id, stage_id: nil) }.to raise_error(described_class::Invalid)
  end

  it 'can be turned off' do
    settings.update!(enabled: false, pipeline_id: nil, stage_id: nil)

    expect(described_class.new(account.reload).enabled?).to be(false)
  end
end
