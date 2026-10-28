class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: [:update, :evolution_edit]
  rescue_from CustomExceptions::Evolution, with: :render_evolution_error

  TRANSCRIBE_ERROR_STATUS = { 'text_ai_disabled' => :forbidden, 'insufficient_balance' => :payment_required }.freeze

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    if permitted_params[:content].present?
      update_content
    else
      Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
      update_content_attributes if permitted_params[:content_attributes].present?
    end
    @message = message
  end

  def evolution_edit
    @message = Evolution::MessageEditSyncService.new(
      message: message,
      content: evolution_edit_params[:content],
      instance_name: evolution_edit_params[:instance_name],
      whatsapp_message_key: evolution_edit_params[:whatsapp_message_key],
      edited_at: evolution_edit_params[:edited_at]
    ).perform
  end

  def destroy
    ActiveRecord::Base.transaction do
      # keeps the forward marker so replies to a deleted forward stay out of this conversation
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text,
                      content_attributes: message.content_attributes.slice('forwarded_message_id').merge(deleted: true))
      message.attachments.destroy_all
    end
    unpin_deleted_note(message)
  end

  def retry
    return if message.blank?
    if !message.private? && @conversation.additional_attributes['evolution_group_left_at'].present?
      return render_could_not_create_error(I18n.t('evolution_groups.errors.group_left'))
    end

    ::SendReplyJob.perform_later(message.id) if claim_message_retry
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  # "Transcrever" button of a received audio. The text reaches the bubble through the message update event.
  def transcribe
    attachment = message.attachments.audio.find(params.require(:attachment_id))
    return head :ok if attachment.meta&.[]('transcribed_text').present?

    error = Saas::Audio::TranscriptionService.new(attachment: attachment, account: Current.account).blocking_error
    return render json: { error: error }, status: TRANSCRIBE_ERROR_STATUS.fetch(error, :unprocessable_entity) if error

    Saas::TranscribeAudioJob.perform_later(attachment.id)
    head :accepted
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  # A deleted note cannot stay pinned on top of the conversation.
  def unpin_deleted_note(message)
    attributes = @conversation.additional_attributes
    return unless attributes.dig('pinned_note', 'message_id') == message.id

    @conversation.update!(additional_attributes: attributes.except('pinned_note'))
  end

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def claim_message_retry
    message.with_lock do
      next false unless message.failed?

      Messages::StatusUpdateService.new(message, 'sent').perform
      clear_source_id unless @conversation.inbox.api? || @conversation.inbox.web_widget?
      true
    end
  end

  def clear_source_id
    Rails.logger.info "Cleared older source ID #{message.source_id} for message #{message.id}" if message.source_id.present?
    message.update!(source_id: nil)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content, content_attributes: {})
  end

  def evolution_edit_params
    params.permit(:content, :instance_name, :edited_at, whatsapp_message_key: {})
  end

  def update_content
    attributes = permitted_params[:content_attributes].to_h.stringify_keys

    Evolution::MessageEditService.new(message: message, content: permitted_params[:content]).perform

    message.update!(
      content: permitted_params[:content],
      content_attributes: merged_content_attributes(
        attributes.merge(
          'whatsapp_message_edited' => true,
          'whatsapp_message_edited_at' => Time.current.iso8601
        )
      ),
      source_id: whatsapp_source_id(attributes) || message.source_id
    )
  end

  def update_content_attributes
    attributes = permitted_params[:content_attributes].to_h.stringify_keys
    message.update!(
      content_attributes: merged_content_attributes(attributes),
      source_id: whatsapp_source_id(attributes) || message.source_id
    )
  end

  def merged_content_attributes(attributes)
    current_attributes = message.content_attributes.to_h.stringify_keys
    current_key = current_attributes['whatsapp_message_key']
    incoming_key = attributes['whatsapp_message_key']

    merged_attributes = current_attributes.merge(attributes)
    if current_key.is_a?(Hash) && incoming_key.is_a?(Hash)
      merged_attributes['whatsapp_message_key'] = if current_key['id'].present? && current_key['id'] != incoming_key['id']
                                                    current_key
                                                  else
                                                    current_key.merge(incoming_key)
                                                  end
    end

    merged_attributes
  end

  def whatsapp_source_id(attributes)
    key = attributes['whatsapp_message_key']
    return unless key.is_a?(Hash) && key['id'].present?

    current_key = message.content_attributes.to_h.stringify_keys['whatsapp_message_key']
    return if conflicting_whatsapp_key?(current_key, key)

    source_id = "WAID:#{key['id']}"
    return if message.source_id.present? && message.source_id != source_id

    source_id
  end

  def conflicting_whatsapp_key?(current_key, incoming_key)
    current_key.is_a?(Hash) && current_key['id'].present? && current_key['id'] != incoming_key['id']
  end

  def render_evolution_error(error)
    render json: { error: error.message, error_code: error.code }, status: error.http_status
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end

Api::V1::Accounts::Conversations::MessagesController.prepend_mod_with('Api::V1::Accounts::Conversations::MessagesController')
