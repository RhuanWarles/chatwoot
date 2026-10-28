# Who can see the CS notes of the contacts: the administrators and the members of the team the administrators chose
# (`cs_team_id` in the account settings). Nobody else, and nobody at all outside those two groups.
class CsNotes::Access
  def initialize(account, user)
    @account = account
    @user = user
  end

  def allowed?
    administrator? || team_member?
  end

  def administrator?
    return false unless @user.is_a?(User)

    @account.account_users.exists?(user_id: @user.id, role: :administrator)
  end

  def team_id
    @account.cs_team_id.presence&.to_i
  end

  private

  def team_member?
    return false unless @user.is_a?(User) && team_id

    TeamMember.joins(:team).exists?(user_id: @user.id, team_id: team_id, teams: { account_id: @account.id })
  end
end
