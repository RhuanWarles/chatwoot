class Api::V1::Accounts::Crm::DealEventsController < Api::V1::Accounts::BaseController
  PAGE_SIZE = 50
  MAX_NOTE_LENGTH = 10_000

  before_action :fetch_deal

  def index
    authorize(@deal, :show?)
    page = params.fetch(:page, '1')
    unless page.is_a?(String) && page.match?(/\A[1-9]\d*\z/)
      render json: { error: 'Invalid page' }, status: :unprocessable_entity
      return
    end
    events = @deal.events.where(account_id: Current.account.id).includes(:actor)
                  .order(created_at: :desc, id: :desc).offset((page.to_i - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
    render json: { payload: events.first(PAGE_SIZE).as_json(include: { actor: { only: [:id, :name] } }), meta: { has_more: events.length > PAGE_SIZE } }
  end

  def create
    authorize(@deal, :update?)
    event_params = params.require(:event)
    body = event_params[:body] if event_params.is_a?(ActionController::Parameters)
    unless body.is_a?(String) && body.strip.present? && body.length <= MAX_NOTE_LENGTH
      render json: { error: 'Note must contain between 1 and 10000 characters' }, status: :unprocessable_entity
      return
    end
    event = @deal.events.create!(
      account_id: Current.account.id, actor: Current.user, event_type: 'note_created', metadata: { body: body.strip }
    )
    render json: event.as_json(include: { actor: { only: [:id, :name] } }), status: :created
  end

  private

  def fetch_deal
    @deal = policy_scope(Crm::Deal).find(params[:deal_id])
  end
end
