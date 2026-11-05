class Workflows::Actions::DealActions
  NAMES = %w[move_deal set_deal_status assign_deal_owner distribute_deal update_deal set_deal_field create_deal create_deal_activity].freeze
  DEFAULT_ACTIVITY_DUE_HOURS = 24

  def initialize(context, workflow)
    @context = context
    @account = context.account
    @workflow = workflow
  end

  def move_deal(params)
    attributes = { pipeline_id: params['pipeline_id'], pipeline_stage_id: params['pipeline_stage_id'] }.compact_blank
    attributes[:status] = 'open' if ActiveModel::Type::Boolean.new.cast(params['reopen'])
    save!(deal, attributes)
    { 'deal_id' => deal.id, 'pipeline_id' => deal.pipeline_id, 'pipeline_stage_id' => deal.pipeline_stage_id, 'status' => deal.status }
  end

  def set_deal_status(params)
    attributes = { status: params['status'] }
    attributes[:lost_reason_id] = params['lost_reason_id'] if params['lost_reason_id'].present?
    attributes[:lost_note] = params['lost_note'] if params['lost_note'].present?
    save!(deal, attributes)
    { 'deal_id' => deal.id, 'status' => deal.status }
  end

  def assign_deal_owner(params)
    owner_id = case params['mode']
               when 'random' then Array(params['user_ids']).sample
               when 'conversation_assignee' then @context.conversation&.assignee_id
               else params['user_id']
               end
    raise ArgumentError, 'there is nobody to assign the deal to' if owner_id.blank?

    save!(deal, owner_id: owner_id)
    fill_user_field(params['custom_field_key'], deal.owner_id)
    { 'deal_id' => deal.id, 'owner_id' => deal.owner_id }
  end

  # Weighted round robin: each person gets the share of leads set for them. The person who is next also becomes the owner
  # of the card, is written in the user field (when chosen) and, by default, takes over the conversation of the lead.
  def distribute_deal(params)
    assignees = distribution_of(params)
    user_id = Workflows::Distribution.pick!(@workflow, @context.node_id || 'manual', assignees)
    save!(deal, owner_id: user_id)
    fill_user_field(params['custom_field_key'], user_id)
    output = { 'deal_id' => deal.id, 'owner_id' => user_id }
    assign_conversation(user_id, output) if ActiveModel::Type::Boolean.new.cast(params.fetch('assign_conversation', true))
    output
  end

  def update_deal(params)
    attributes = params.slice('name', 'value', 'description', 'segment_id').compact_blank.symbolize_keys
    save!(deal, attributes)
    { 'deal_id' => deal.id }
  end

  def set_deal_field(params)
    keys = Array(params['fields']).map { |item| item['key'].to_s }
    fields = @account.crm_custom_fields.where(active: true, key: keys).index_by(&:key)
    Array(params['fields']).each do |item|
      field = fields[item['key'].to_s] || raise(Workflows::ActionRunner::MissingRecord, "CRM custom field #{item['key']} not found")
      write_field(field, item['value'])
    end
    { 'deal_id' => deal.id, 'fields' => keys }
  end

  def create_deal(params)
    contact = @context.contact || raise(Workflows::ActionRunner::MissingRecord, 'No contact is available for this run')
    created = Crm::Deal.new(account: @account, contact: contact, pipeline_id: params['pipeline_id'], pipeline_stage_id: params['pipeline_stage_id'],
                            name: params['name'].presence || contact.name, value: params['value'].presence, owner_id: params['owner_id'].presence)
    created.automation_depth = depth
    created.save!
    @context.use_deal(created)
    { 'deal_id' => created.id }
  end

  def create_deal_activity(params)
    hours = params['due_in_hours'].presence&.to_i || DEFAULT_ACTIVITY_DUE_HOURS
    activity = deal.activities.create!(
      account_id: @account.id, contact_id: deal.contact_id, owner_id: deal.owner_id,
      activity_type: params['activity_type'], title: params['title'], due_at: hours.hours.from_now
    )
    { 'activity_id' => activity.id }
  end

  private

  # The people of the distribution, checked before anything is changed.
  def distribution_of(params)
    assignees = Array(params['assignees'])
    messages = Workflows::Distribution.errors(assignees)
    raise ArgumentError, messages.first if messages.any?

    ids = assignees.map { |item| Integer(item['user_id']) }
    raise ArgumentError, 'a person of the distribution does not belong to the account' unless @account.users.where(id: ids).count == ids.size

    assignees
  end

  # A lead without a conversation still gets its owner; the output tells that nobody was assigned there.
  def assign_conversation(user_id, output)
    return output['conversation_id'] = nil unless @context.conversation

    Workflows::Actions::ConversationActions.new(@context, @workflow).assign_agent('agent_id' => user_id.to_s)
    output['conversation_id'] = @context.conversation.id
  end

  def fill_user_field(key, user_id)
    return if key.blank?

    field = @account.crm_custom_fields.find_by(key: key.to_s, active: true) ||
            raise(Workflows::ActionRunner::MissingRecord, "CRM custom field #{key} not found")
    raise ArgumentError, "CRM custom field #{key} is not a user field" unless field.field_type == 'user'

    write_field(field, user_id)
  end

  def deal
    @context.deal || raise(Workflows::ActionRunner::MissingRecord, 'No CRM deal is available for this run')
  end

  # What a workflow changes enqueues the pipeline's own automations one level deeper than the event that started it,
  # so a ring made of pipeline automations and workflows ends at the pipeline automations' depth limit.
  def depth
    @context.automation_depth + 1
  end

  def save!(record, attributes)
    record.assign_attributes(attributes)
    record.automation_depth = depth
    record.save!
  end

  def write_field(field, value)
    record = deal.custom_field_values.find_or_initialize_by(custom_field: field)
    record.account_id = @account.id
    record.automation_depth = depth
    record.typed_value = value
    record.save!
  end
end
