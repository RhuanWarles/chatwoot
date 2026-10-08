class Api::V1::Accounts::WhatsappGroupsController < Api::V1::Accounts::BaseController
  rescue_from CustomExceptions::Evolution do |error|
    render json: { error: error.message, error_code: error.code }, status: error.http_status
  end

  def index
    inboxes = policy_scope(Current.account.inboxes).where(account_id: Current.account.id).includes(:channel)
    render json: { inboxes: inboxes.select { |inbox| Evolution::Configuration.new(inbox).eligible? }.map { |inbox| inbox.slice(:id, :name) } }
  end

  def create
    inbox = Current.account.inboxes.find(params.require(:inbox_id))
    authorize inbox, :show?
    subject = params[:subject]
    request_id = params[:request_id]
    unless subject.is_a?(String) && subject.strip.present? && subject.strip.length <= 100 &&
           request_id.is_a?(String) && request_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      raise CustomExceptions::Evolution, :invalid_request
    end

    conversation = Evolution::CreateGroupService.new(
      inbox: inbox, user: Current.user, subject: subject.strip,
      participants: params[:participants], request_id: request_id
    ).perform
    render json: { conversation_id: conversation.display_id, group_jid: conversation.contact_inbox.source_id }, status: :created
  end
end
