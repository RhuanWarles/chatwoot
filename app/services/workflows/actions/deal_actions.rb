class Workflows::Actions::DealActions
  NAMES = %w[move_deal set_deal_status assign_deal_owner update_deal set_deal_field create_deal create_deal_activity].freeze
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
    { 'deal_id' => deal.id, 'owner_id' => deal.owner_id }
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
