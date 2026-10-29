require 'rails_helper'

RSpec.describe Crm::DealPolicy::Scope do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:own_deal) { create_deal('Meu', agent) }
  let!(:colleague_deal) { create_deal('Do colega', colleague) }
  let!(:ownerless_deal) { create_deal('Sem dono', nil) }

  def create_deal(name, owner)
    account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: create(:contact, account: account), name: name, owner: owner)
  end

  def resolve(user)
    context = { user: user, account: account, account_user: user.account_users.find_by(account: account) }
    described_class.new(context, Crm::Deal).resolve
  end

  it 'gives a plain agent only the cards they own' do
    expect(resolve(agent)).to contain_exactly(own_deal)
  end

  it 'gives administrators every card of the account, ownerless ones included' do
    expect(resolve(administrator)).to contain_exactly(own_deal, colleague_deal, ownerless_deal)
  end

  it 'does not leak cards of other accounts' do
    other_account = create(:account)
    other_pipeline = other_account.crm_pipelines.create!(name: 'Outra')
    other_stage = other_account.crm_pipeline_stages.create!(pipeline: other_pipeline, name: 'Novo', position: 0)
    other_account.crm_deals.create!(pipeline: other_pipeline, pipeline_stage: other_stage, contact: create(:contact, account: other_account),
                                    name: 'Alheio')

    expect(resolve(administrator).pluck(:name)).not_to include('Alheio')
  end

  it 'keeps what a custom role agent sees as it was' do
    custom_role = create(:custom_role, account: account)
    agent.account_users.find_by(account: account).update!(custom_role: custom_role)

    expect(resolve(agent)).to contain_exactly(own_deal, colleague_deal, ownerless_deal)
  end
end
