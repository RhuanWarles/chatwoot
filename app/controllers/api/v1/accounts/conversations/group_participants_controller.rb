# frozen_string_literal: true

class Api::V1::Accounts::Conversations::GroupParticipantsController < Api::V1::Accounts::BaseController
  before_action :conversation
  rescue_from CustomExceptions::Evolution do |error|
    render json: { error: error.message, error_code: error.code }, status: error.http_status
  end

  def show
    authorize @conversation, :show?
    return head :not_found unless group_conversation?

    participants = Evolution::GroupParticipantsService.new(@conversation).perform(strict: true)
    can_add = Evolution::Configuration.new(@conversation.inbox).eligible? &&
              @conversation.additional_attributes['evolution_group_left_at'].blank?
    render json: { participants: participants, can_add: can_add }
  end

  def create
    authorize @conversation, :show?
    return head :not_found unless group_conversation?

    participants = Evolution::UpdateGroupParticipantService.new(conversation: @conversation, participants: params[:participants]).perform
    render json: { participants: participants }
  end

  private

  def conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def group_conversation?
    source_id = @conversation.contact_inbox&.source_id.to_s
    return true if source_id.end_with?('@g.us')

    @conversation.contact&.identifier.to_s.end_with?('@g.us')
  end
end
