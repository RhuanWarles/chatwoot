class Api::V1::Accounts::Conversations::MessageReactionsController < Api::V1::Accounts::Conversations::BaseController
  IDENTIFIER = ->(value) { value.is_a?(String) && value.length.between?(1, 200) }
  EVENT_VALIDATORS = {
    emoji: ->(value) { value.is_a?(String) && value.length <= 32 },
    from_me: ->(value) { [true, false].include?(value) },
    timestamp_ms: ->(value) { value.is_a?(Integer) && value.positive? },
    event_id: IDENTIFIER, target_id: IDENTIFIER,
    participant: ->(value) { value.is_a?(String) && (value.empty? || value.match?(/\A\d+(?::\d+)?@(lid|s\.whatsapp\.net)\z/)) },
    name: ->(value) { value.nil? || (value.is_a?(String) && value.length <= 200) }
  }.freeze

  before_action :authenticate_provider!, only: :receive
  rescue_from CustomExceptions::Evolution, with: :render_provider_error

  def create
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User)

    emoji = params[:emoji]
    unless emoji.is_a?(String) && (Evolution::MessageReactionsService::EMOJIS.include?(emoji) || emoji.empty?)
      raise CustomExceptions::Evolution, :invalid_reaction
    end

    message = @conversation.messages.find(params[:message_id])
    ensure_group!
    records = Evolution::MessageReactionsService.new(message).send!(emoji, Current.user)
    render json: { reactions: records }
  end

  def receive
    event = validated_event
    raise CustomExceptions::Evolution, :invalid_reaction unless event.delete('group_jid') == ensure_group!

    target_id = event.delete('target_id')
    message = @conversation.messages.find_by(source_id: [target_id, "WAID:#{target_id}"])
    unless message
      Rails.logger.info("[Evolution] reaction target unavailable account=#{Current.account.id} conversation=#{@conversation.id}")
      return render json: { ignored: 'target_not_found' }, status: :accepted
    end

    records = Evolution::MessageReactionsService.new(message).receive!(event)
    render json: { reactions: records }
  end

  private

  def authenticate_provider!
    expected = ENV.fetch('EVOLUTION_API_KEY')
    supplied = request.headers['X-Evolution-Reaction-Key'].to_s
    raise Pundit::NotAuthorizedError unless supplied.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
  end

  def validated_event
    input = params.require(:reaction)
    valid = input.is_a?(ActionController::Parameters) && EVENT_VALIDATORS.all? { |key, validator| validator.call(input[key]) }
    raise CustomExceptions::Evolution, :invalid_reaction unless valid && (input[:from_me] || input[:participant].present?)

    input.permit(*EVENT_VALIDATORS.keys, :group_jid).to_h
  end

  def ensure_group!
    configuration = Evolution::Configuration.new(@conversation.inbox)
    raise CustomExceptions::Evolution, :not_configured unless configuration.eligible?

    Evolution::GroupContext.new(@conversation).group_jid
  end

  def render_provider_error(error)
    render json: { error: error.code, message: error.message }, status: error.http_status
  end
end
