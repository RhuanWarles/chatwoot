class Api::V1::Accounts::Conversations::GroupsController < Api::V1::Accounts::BaseController
  before_action :load_conversation
  before_action :authorize_management, except: :show
  rescue_from CustomExceptions::Evolution do |error|
    render json: { error: error.message, error_code: error.code }, status: error.http_status
  end

  def show
    authorize @conversation, :show?
    render_group
  end

  def update
    if params.key?(:picture) && !params.key?(:subject)
      Evolution::UpdateGroupPictureService.new(conversation: @conversation, picture: params[:picture]).perform
    elsif params.key?(:subject) && !params.key?(:picture)
      Evolution::UpdateGroupSubjectService.new(conversation: @conversation, subject: params[:subject]).perform
    else
      raise CustomExceptions::Evolution, :invalid_request
    end
    render_group
  end

  def participants
    if params[:operation] == 'remove' && params[:confirmed] != true
      raise CustomExceptions::Evolution, :confirmation_required
    end

    Evolution::GroupParticipantActionService.new(
      conversation: @conversation, action: params[:operation], participant_id: params[:participant_id]
    ).perform
    render_group
  end

  def leave
    raise CustomExceptions::Evolution, :confirmation_required unless params[:confirmed] == true

    Evolution::LeaveGroupService.new(conversation: @conversation, user: Current.user).perform
    render_group
  end

  private

  def load_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    Evolution::GroupContext.new(@conversation).group_jid
  end

  def authorize_management
    authorize @conversation, :manage?, policy_class: ConversationGroupPolicy
  end

  def render_group
    data = Evolution::GroupInfoService.new(@conversation).perform
    manager = ConversationGroupPolicy.new(pundit_user, @conversation).manage?
    render json: data.merge(
      can_manage: manager && data[:instance_admin], can_leave: manager && data[:instance_member],
      contact: @conversation.contact.reload.push_event_data,
      additional_attributes: @conversation.reload.additional_attributes, can_reply: @conversation.can_reply?
    )
  end
end
