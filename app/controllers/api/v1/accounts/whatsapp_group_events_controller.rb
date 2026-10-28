class Api::V1::Accounts::WhatsappGroupEventsController < Api::V1::Accounts::BaseController
  before_action :authenticate_provider!

  def create
    Evolution::GroupParticipantEventService.new(
      account: Current.account,
      group_jid: event_params[:group_jid],
      action: event_params[:action],
      participant: event_params[:participant],
      participant_name: event_params[:participant_name],
      event_id: event_params[:event_id]
    ).perform

    head :accepted
  end

  private

  def authenticate_provider!
    expected = ENV.fetch('EVOLUTION_API_KEY')
    supplied = request.headers['X-Evolution-Reaction-Key'].to_s
    raise Pundit::NotAuthorizedError unless supplied.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
  end

  def event_params
    params.require(:event).permit(:group_jid, :action, :participant, :participant_name, :event_id).tap do |event|
      raise ActionController::ParameterMissing, :group_jid unless event[:group_jid].to_s.match?(/\A\d+@g\.us\z/)
      raise ActionController::ParameterMissing, :participant if event[:participant].blank?
      raise ActionController::ParameterMissing, :action unless event[:action].to_s == 'remove'
    end
  end
end
