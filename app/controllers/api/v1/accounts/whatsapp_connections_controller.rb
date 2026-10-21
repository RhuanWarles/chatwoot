class Api::V1::Accounts::WhatsappConnectionsController < Api::V1::Accounts::BaseController
  before_action :ensure_available
  before_action :check_admin_authorization?
  before_action :set_connection, except: [:index, :create]

  rescue_from CustomExceptions::WhatsappConnection do |error|
    @connection.update!(status: 'error') if @connection&.persisted? && error.http_status == 502 && action_name == 'create'
    render json: {
      error: error.code == 'unavailable' ? 'evolution_unavailable' : error.code,
      message: error.message,
      error_code: error.code,
      connection: @connection && connection_payload(@connection)
    }, status: error.http_status
  end

  rescue_from CustomExceptions::Evolution do |error|
    render json: {
      error: error.code == 'unavailable' ? 'evolution_unavailable' : error.code,
      message: error.message,
      error_code: error.code,
      connection: @connection && connection_payload(@connection)
    }, status: error.http_status
  end

  def index
    connections = Current.account.whatsapp_connections.includes(:inbox).order(:id)
    inboxes = Current.account.inboxes.where(channel_type: 'Channel::Api').includes(:channel).order_by_name
    render json: {
      connections: connections.map { |connection| connection_payload(connection) },
      inboxes: inboxes.map do |inbox|
        { id: inbox.id, name: inbox.name, legacy_instance_name: inbox.channel.additional_attributes['evolution_instance_name'] }
      end
    }
  end

  def show
    qr_code = manager.refresh!
    render json: connection_payload(@connection, include_configuration: true).merge(qr_code: qr_code)
  end

  def create
    attributes = connection_params(creating: true)
    Evolution::ConnectionManager.validate_inbox!(Current.account.inboxes.find(attributes[:inbox_id])) if attributes[:inbox_id]
    @connection = Current.account.whatsapp_connections.create!(
      display_name: attributes.fetch(:display_name), instance_name: "account-#{Current.account.id}-#{SecureRandom.hex(8)}"
    )
    qr_code = manager.provision!(attributes[:inbox_id])
    render json: connection_payload(@connection).merge(qr_code: qr_code), status: :created
  end

  def update
    attributes = connection_params
    manager.update!(attributes)
    render json: connection_payload(@connection, include_configuration: attributes.key?(:sign_msg))
  end

  def connect
    regenerate = params.fetch(:regenerate, false)
    raise CustomExceptions::WhatsappConnection, :invalid_request unless [true, false].include?(regenerate)

    qr_code = manager.connect!(regenerate: regenerate)
    render json: connection_payload(@connection).merge(qr_code: qr_code)
  end

  def disconnect
    manager.disconnect!
    render json: connection_payload(@connection)
  end

  def destroy
    manager.destroy!
    head :no_content
  end

  private

  def ensure_available
    head :not_found unless Evolution::Configuration.available?
  end

  def set_connection
    @connection = Current.account.whatsapp_connections.find(params[:id])
  end

  def manager
    Evolution::ConnectionManager.new(@connection, Current.user)
  end

  def connection_params(creating: false)
    attributes = params.permit(:display_name, :inbox_id, :sign_msg).to_h.symbolize_keys
    attributes[:display_name] = validated_name(attributes[:display_name]) if creating || attributes.key?(:display_name)
    validate_inbox_id!(attributes[:inbox_id])
    validate_sign_msg!(attributes[:sign_msg]) if attributes.key?(:sign_msg)

    attributes
  end

  def validate_inbox_id!(inbox_id)
    return if inbox_id.nil? || (inbox_id.is_a?(Integer) && inbox_id.positive?)

    raise CustomExceptions::WhatsappConnection, :invalid_inbox
  end

  def validate_sign_msg!(sign_msg)
    return if [true, false].include?(sign_msg)

    raise CustomExceptions::WhatsappConnection, :invalid_request
  end

  def validated_name(name)
    raise CustomExceptions::WhatsappConnection, :invalid_name unless name.is_a?(String) && name.strip.present? && name.strip.length <= 100

    name.strip
  end

  def connection_payload(connection, include_configuration: false)
    payload = connection.slice(
      :id, :display_name, :instance_name, :inbox_id, :phone_number, :profile_name, :profile_picture_url, :status
    ).merge(inbox: connection.inbox&.slice(:id, :name))
    return payload unless include_configuration && connection.inbox

    payload.merge(sign_msg: Evolution::ChatwootConfiguration.new(connection.inbox).show[:sign_msg])
  end
end
