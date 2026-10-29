class Webhooks::AutomationWorkflowsController < ActionController::API
  PAYLOAD_PARAMS_TO_SKIP = %w[token controller action].freeze
  MAX_BODY_BYTES = 64.kilobytes

  wrap_parameters false

  def create
    workflow = AutomationWorkflow.active.find_by(webhook_token: request.path_parameters[:token])
    return head :not_found unless workflow
    return head :payload_too_large if request.content_length.to_i > MAX_BODY_BYTES

    body = request.request_parameters.except(*PAYLOAD_PARAMS_TO_SKIP)
    run = Workflows::TriggerService.start(workflow, 'webhook', record_ids(workflow.account, body).merge('payload' => body))
    return head :unprocessable_entity unless run

    render json: { run_id: run.id }, status: :accepted
  end

  private

  # The caller says which records the run is about: ids (a conversation by its display id) or the contact's email / phone number.
  def record_ids(account, body)
    contact = account.contacts.find_by(email: body['email'].to_s.downcase) if body['email'].present?
    contact ||= account.contacts.find_by(phone_number: body['phone_number']) if body['phone_number'].present?
    {
      'deal_id' => account.crm_deals.find_by(id: body['deal_id'])&.id,
      'contact_id' => account.contacts.find_by(id: body['contact_id'])&.id || contact&.id,
      'conversation_id' => account.conversations.find_by(display_id: body['conversation_id'])&.id
    }.compact
  end
end
