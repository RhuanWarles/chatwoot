require 'rails_helper'

RSpec.describe CsNotes::Access do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def access_for(user)
    described_class.new(account.reload, user)
  end

  it 'lets the administrators in, even before a team was chosen' do
    expect(access_for(admin)).to be_allowed
    expect(access_for(admin)).to be_administrator
  end

  it 'keeps the agents out while no team was chosen' do
    expect(access_for(agent)).not_to be_allowed
  end

  context 'when a team was chosen' do
    before { account.update!(cs_team_id: team.id) }

    it 'lets in the members of that team' do
      create(:team_member, team: team, user: agent)

      expect(access_for(agent)).to be_allowed
      expect(access_for(agent)).not_to be_administrator
    end

    it 'keeps out an agent who is in another team' do
      create(:team_member, team: create(:team, account: account), user: agent)

      expect(access_for(agent)).not_to be_allowed
    end

    it 'keeps out someone who left the team' do
      member = create(:team_member, team: team, user: agent)
      member.destroy!

      expect(access_for(agent)).not_to be_allowed
    end

    it 'does not trust a team id that belongs to another account' do
      foreign_team = create(:team)
      account.update!(cs_team_id: foreign_team.id)
      create(:team_member, team: foreign_team, user: agent)

      expect(access_for(agent)).not_to be_allowed
    end
  end

  it 'keeps out whoever is not a user (a bot, no one)' do
    expect(access_for(nil)).not_to be_allowed
    expect(access_for(create(:agent_bot))).not_to be_allowed
  end
end
