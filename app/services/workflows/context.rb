# Holds what a run knows (the records its ids point to) and exposes it to conditions and templates through
# a fixed allowlist of fields, so a workflow can never call arbitrary methods on a record.
class Workflows::Context
  TOKEN = /\{\{\s*([\w.]+)\s*\}\}/
  CHANGE_KEYS = %w[pipeline_id pipeline_stage_id status owner_id value segment_id lost_reason_id name assignee_id team_id priority].freeze

  attr_reader :account, :run, :state

  def initialize(run)
    @run = run
    @account = run.account
    @state = run.context
    @state['vars'] ||= {}
  end

  def conversation
    @conversation ||= account.conversations.find_by(id: state['conversation_id']) ||
                      contact&.conversations&.reorder(last_activity_at: :desc)&.first
  end

  def contact
    return @contact if defined?(@contact)

    @contact = account.contacts.find_by(id: state['contact_id']) || deal_record&.contact || conversation_record&.contact
  end

  # The deal of the event, or else (when the run has none) the most recent open deal of the contact, so conversation
  # triggers can act on the card. A run whose deal was deleted has no deal rather than another one.
  def deal
    @deal ||= deal_record || (state['deal_id'].blank? ? latest_open_deal : nil)
  end

  def automation_depth
    state['automation_depth'].to_i
  end

  def message
    return @message if defined?(@message)

    @message = account.messages.find_by(id: state['message_id'])
  end

  def vars
    state['vars']
  end

  def use_deal(new_deal)
    state['deal_id'] = new_deal.id
    reload!
  end

  # Actions change the records, so the next node must read them again.
  def reload!
    @conversation = @conversation_record = @deal = @deal_record = @data = nil
    remove_instance_variable(:@contact) if defined?(@contact)
    remove_instance_variable(:@message) if defined?(@message)
  end

  def value(path)
    path.to_s.split('.').inject(data) { |memo, key| memo.is_a?(Hash) ? memo[key] : nil }
  end

  # `escape` encodes every substituted value, for places where the text of a customer must not change the shape of the result.
  def render(input, escape: nil)
    case input
    when String then input.gsub(TOKEN) { substitute(Regexp.last_match(1), escape) }
    when Hash then input.transform_values { |item| render(item, escape: escape) }
    when Array then input.map { |item| render(item, escape: escape) }
    else input
    end
  end

  def payload
    data.slice('deal', 'contact', 'conversation', 'message').merge(
      'event' => run.trigger_event, 'workflow' => { 'id' => run.automation_workflow_id, 'name' => run.automation_workflow.name }
    )
  end

  private

  def data
    @data ||= {
      'deal' => deal_data, 'contact' => contact_data, 'conversation' => conversation_data, 'message' => message_data,
      'change' => change_data, 'vars' => vars,
      'trigger' => { 'event' => run.trigger_event, 'payload' => state['payload'] || {}, 'field' => changed_field_key }
    }
  end

  def latest_open_deal
    account.crm_deals.where(contact_id: state['contact_id'] || conversation_record&.contact_id, status: 'open').order(updated_at: :desc).first
  end

  # For a "custom field changed" trigger: the key of the field that changed (`change.value` is then that field's value).
  def changed_field_key
    account.crm_custom_fields.find_by(id: state['custom_field_id'])&.key if state['custom_field_id']
  end

  def deal_record
    @deal_record ||= account.crm_deals.find_by(id: state['deal_id'])
  end

  def conversation_record
    @conversation_record ||= account.conversations.find_by(id: state['conversation_id'])
  end

  def deal_data
    return {} unless deal

    {
      'id' => deal.id, 'name' => deal.name, 'status' => deal.status, 'value' => number(deal.value), 'description' => deal.description,
      'pipeline_id' => deal.pipeline_id, 'pipeline_stage_id' => deal.pipeline_stage_id, 'owner_id' => deal.owner_id,
      'segment_id' => deal.segment_id, 'lost_reason_id' => deal.lost_reason_id, 'lost_reason' => deal.lost_reason&.name,
      'lost_note' => deal.lost_note, 'pipeline' => deal.pipeline.name, 'stage' => deal.pipeline_stage.name, 'owner' => deal.owner&.name,
      'custom' => deal.custom_field_values.includes(:custom_field).to_h { |item| [item.custom_field.key, item.typed_value] }
    }
  end

  def contact_data
    return {} unless contact

    {
      'id' => contact.id, 'name' => contact.name, 'email' => contact.email, 'phone_number' => contact.phone_number,
      'custom' => contact.custom_attributes.to_h, 'labels' => contact.label_list
    }
  end

  def conversation_data
    return {} unless conversation

    {
      'id' => conversation.id, 'display_id' => conversation.display_id, 'status' => conversation.status, 'inbox_id' => conversation.inbox_id,
      'assignee_id' => conversation.assignee_id, 'team_id' => conversation.team_id, 'priority' => conversation.priority,
      'labels' => conversation.label_list
    }
  end

  def message_data
    return {} unless message

    { 'id' => message.id, 'content' => message.content, 'message_type' => message.message_type }
  end

  def change_data
    state.fetch('changes', {}).slice(*CHANGE_KEYS).transform_values { |(from, to)| { 'from' => from, 'to' => to } }
  end

  def number(value)
    return value if value.nil?

    value.frac.zero? ? value.to_i : value.to_f
  end

  def substitute(path, escape)
    text = format_value(value(path))
    escape ? escape.call(text) : text
  end

  def format_value(value)
    value.is_a?(Array) ? value.join(', ') : value.to_s
  end
end
