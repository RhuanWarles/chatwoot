class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      allowed_screens: screens_params[:allowed_screens],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
    join_inboxes(@agent) if inbox_ids_given?
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact.merge(screens_params))
    sync_inboxes(@agent) if inbox_ids_given?
  end

  # Marks the e-mail of an agent as confirmed, for installations where the invitation e-mail never arrives.
  def confirm
    @agent.confirm unless @agent.confirmed?
    render :update
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    bulk_create_agents(emails)
    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    clear_onboarding_step
    head :ok
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline]
  end

  helper_method :agent_inbox_ids

  def inbox_ids_given?
    params[:agent]&.key?(:inbox_ids)
  end

  def requested_inboxes
    Current.account.inboxes.where(id: Array(params.require(:agent)[:inbox_ids]).compact_blank)
  end

  def join_inboxes(agent)
    requested_inboxes.each do |inbox|
      inbox.add_members([agent.id]) unless inbox.inbox_members.exists?(user_id: agent.id)
    end
  end

  # The agent ends up in exactly the requested inboxes of this account (inboxes of other accounts are never touched).
  def sync_inboxes(agent)
    requested = requested_inboxes.to_a
    Current.account.inboxes.where.not(id: requested.map(&:id)).each do |inbox|
      inbox.remove_members([agent.id]) if inbox.inbox_members.exists?(user_id: agent.id)
    end
    join_inboxes(agent)
  end

  # allowed_screens: null (or an empty list) gives access to everything, so the key must be read even when it is nil.
  def screens_params
    return {} unless params[:agent]&.key?(:allowed_screens)

    { allowed_screens: Array(params[:agent][:allowed_screens]).presence }
  end

  def agent_inbox_ids(agent)
    @agent_inbox_ids ||= InboxMember.where(inbox_id: Current.account.inboxes.select(:id), user_id: Array(@agents || @agent).map(&:id))
                                    .pluck(:user_id, :inbox_id).group_by(&:first).transform_values { |rows| rows.map(&:last) }
    @agent_inbox_ids.fetch(agent.id, [])
  end

  def allowed_agent_params
    [:name, :email, :role, :availability, :auto_offline]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def bulk_create_agents(emails)
    email_limit_error = nil

    Current.account.with_lock do
      raise AgentBuilder::LimitExceededError if emails.count > available_agent_count

      emails.each do |email|
        create_agent_from_email(email)
      rescue CustomExceptions::Account::EmailLimitExceeded => e
        email_limit_error = e
      end
    end

    raise email_limit_error if email_limit_error
  end

  def create_agent_from_email(email)
    builder = AgentBuilder.new(
      email: email,
      name: email.split('@').first,
      inviter: current_user,
      account: Current.account
    )
    builder.perform
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
  end

  def clear_onboarding_step
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - Current.account.account_users.count
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
