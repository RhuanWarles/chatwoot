class Evolution::ConnectionManager
  STATES = { 'open' => 'connected', 'connecting' => 'connecting', 'close' => 'disconnected', 'refused' => 'error' }.freeze

  def self.validate_inbox!(inbox)
    raise CustomExceptions::WhatsappConnection, :invalid_inbox unless inbox.api?
    raise CustomExceptions::WhatsappConnection, :inbox_in_use if inbox.whatsapp_connection.present?
    raise CustomExceptions::WhatsappConnection, :ambiguous_inbox if inbox.account.inboxes.where(name: inbox.name).where.not(id: inbox.id).exists?
    raise CustomExceptions::WhatsappConnection, :missing_frontend_url if ENV['FRONTEND_URL'].blank?
  end

  def initialize(connection, user)
    @connection = connection
    @user = user
    @client = Evolution::InstanceClient.new(connection)
  end

  def provision!(inbox_id)
    payload = @client.create
    @connection.update!(evolution_instance_id: payload.fetch('instance').fetch('instanceId'))
    update!(inbox_id: inbox_id) if inbox_id
    connect!
  end

  def refresh!
    @connection.with_lock do
      state = @client.state
      profile = @client.profile
      @connection.update!(
        status: STATES.fetch(state, 'error'), evolution_instance_id: profile.fetch('id'),
        phone_number: profile['number'].presence || profile['ownerJid']&.split('@')&.first&.split(':')&.first,
        profile_name: profile['profileName'], profile_picture_url: profile['profilePicUrl']
      )
      qr_code(@client.connect) if @connection.status == 'connecting'
    end
  end

  def connect!(regenerate: false)
    @connection.with_lock do
      state = @client.state
      if state == 'open'
        @connection.update!(status: 'connected')
        return
      end
      @client.restart if regenerate && state == 'connecting'
      payload = @client.connect
      next_state = payload.dig('instance', 'state') || payload.dig('instance', 'status') || 'connecting'
      @connection.update!(status: STATES.fetch(next_state, 'error'))
      qr_code(payload)
    end
  end

  def disconnect!
    @connection.with_lock do
      @client.disconnect unless @client.state == 'close'
      @connection.update!(status: 'disconnected')
    end
  end

  def update!(attributes)
    @connection.with_lock do
      if attributes.key?(:inbox_id) && attributes[:inbox_id] != @connection.inbox_id
        replace_inbox!(attributes[:inbox_id], sign_msg: attributes[:sign_msg])
      elsif attributes.key?(:sign_msg)
        raise CustomExceptions::WhatsappConnection, :invalid_inbox unless @connection.inbox

        Evolution::ChatwootConfiguration.new(@connection.inbox).update_sign_msg(attributes[:sign_msg])
      end
      @connection.update!(attributes.slice(:display_name))
    end
  end

  def destroy!
    @connection.with_lock do
      @client.delete
      clear_inbox!(@connection.inbox)
      @connection.destroy!
    end
  end

  private

  def replace_inbox!(inbox_id, sign_msg: nil)
    inboxes = @connection.account.inboxes.where(id: [@connection.inbox_id, inbox_id].compact).order(:id).lock.to_a
    inbox = inbox_id ? inboxes.find { |item| item.id == inbox_id } || raise(ActiveRecord::RecordNotFound) : nil
    self.class.validate_inbox!(inbox) if inbox
    @client.configure_inbox(inbox, @user, sign_msg: sign_msg)
    clear_inbox!(@connection.inbox)
    @connection.update!(inbox: inbox)
    return unless inbox

    channel = inbox.channel
    channel.with_lock do
      channel.update!(webhook_url: @client.webhook_url,
                      additional_attributes: channel.additional_attributes.merge('evolution_instance_name' => @connection.instance_name))
    end
  end

  def clear_inbox!(inbox)
    return unless inbox

    inbox.channel.with_lock do
      attributes = inbox.channel.additional_attributes
      return unless attributes['evolution_instance_name'] == @connection.instance_name

      changes = { additional_attributes: attributes.except('evolution_instance_name') }
      changes[:webhook_url] = nil if inbox.channel.webhook_url == @client.webhook_url
      inbox.channel.update!(changes)
    end
  end

  def qr_code(payload)
    value = payload['base64']
    value if value.is_a?(String) && value.match?(%r{\Adata:image/png;base64,[A-Za-z0-9+/=\r\n]+\z})
  end
end
