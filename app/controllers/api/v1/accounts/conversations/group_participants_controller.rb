# frozen_string_literal: true

class Api::V1::Accounts::Conversations::GroupParticipantsController < Api::V1::Accounts::BaseController
  before_action :conversation

  def show
    authorize @conversation, :show?
    return head :not_found unless group_conversation?

    participants = Evolution::GroupParticipantsService.new(@conversation).perform
    render json: { participants: participants }
  end

  private

  def conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end

  def group_conversation?
    source_id = @conversation.contact_inbox&.source_id.to_s
    return true if source_id.end_with?('@g.us')

    @conversation.contact&.identifier.to_s.end_with?('@g.us')
  end
end
