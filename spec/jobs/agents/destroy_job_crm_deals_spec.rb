require 'rails_helper'

RSpec.describe Agents::DestroyJob, 'CRM cards' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }

  def create_deal(owner)
    account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: 'Lead', owner: owner)
  end

  it 'leaves the cards of the agent without an owner and keeps the others' do
    own = create_deal(agent)
    colleague_deal = create_deal(colleague)

    described_class.perform_now(account, agent)

    expect(own.reload.owner_id).to be_nil
    expect(colleague_deal.reload.owner_id).to eq(colleague.id)
  end
end
