require 'json'

class AutomationRules::ConditionsFilterService < FilterService
  ATTRIBUTE_MODEL = 'contact_attribute'.freeze
  CRM_ATTRIBUTES = {
    'crm_deal_pipeline_id' => 'pipeline_id', 'crm_deal_pipeline_stage_id' => 'pipeline_stage_id',
    'crm_deal_status' => 'status', 'crm_deal_owner_id' => 'owner_id', 'crm_deal_value' => 'value',
    'crm_deal_segment_id' => 'segment_id'
  }.freeze

  def initialize(rule, conversation = nil, options = {})
    super([], nil)
    # assign rule, conversation and account to instance variables
    @rule = rule
    @conversation = conversation
    @deal = options[:deal]
    @contact = options[:contact]
    @account = conversation&.account || @deal&.account
    @account ||= @contact&.account

    # setup filters from json file
    file = File.read('./lib/filters/filter_keys.yml')
    @filters = YAML.safe_load(file)

    @conversation_filters = @filters['conversations']
    @contact_filters = @filters['contacts']
    @message_filters = @filters['messages']

    @options = options
    @changed_attributes = options[:changed_attributes]
  end

  # Captain is asked only when its answer can change the outcome. AND and OR never negate a condition,
  # so a rule that gives the same result with every Captain condition unmet and met gives that result
  # whatever Captain would answer.
  def perform
    return false unless rule_valid?
    return matches_deal_conditions? if @conversation.nil? && @deal.present?
    return matches_contact_conditions? if @conversation.nil? && @contact.present?
    return matches?({}) if captain_indexes.empty?

    unmet_result = matches?(captain_indexes.index_with(false))
    return unmet_result if unmet_result == matches?(captain_indexes.index_with(true))

    matches?(Captain::AutomationConditionService.new(
      conditions: @rule.conditions, conversation: @conversation, message: @options[:message]
    ).perform)
  rescue StandardError => e
    Rails.logger.error "Error in AutomationRules::ConditionsFilterService: #{e.message}"
    Rails.logger.info "AutomationRules::ConditionsFilterService failed while processing rule #{@rule.id} for conversation #{@conversation&.id}"
    false
  end

  def matches_contact_conditions?
    groups = grouped_conditions
    result = nil
    groups.each_with_index do |group, index|
      group_result = group.all? do |condition|
        key = condition['attribute_key']
        if condition['filter_operator'] == 'attribute_changed'
          change = @options[:changed_attributes].to_h.with_indifferent_access[key]
          expected = condition['values'].is_a?(Hash) ? condition['values'].with_indifferent_access : {}
          next change.present? && Array(expected[:from]).map(&:to_s).include?(change[0].to_s) && Array(expected[:to]).map(&:to_s).include?(change[1].to_s)
        end
        actual = if key == 'crm_contact_custom_field'
                   @contact.custom_attributes[Array(condition['values']).first]
                 elsif @contact.respond_to?(key)
                   @contact.public_send(key)
                 end
        compare_crm_value(actual, condition['filter_operator'], Array(condition['values']).last)
      end
      operator = index.zero? ? 'AND' : condition_group_operator(index)
      result = result.nil? ? group_result : (operator.to_s.casecmp('OR').zero? ? result || group_result : result && group_result)
    end
    result == true
  end

  def matches_deal_conditions?
    groups = grouped_conditions
    return false unless groups.flatten.all? { |condition| crm_attribute?(condition['attribute_key']) }

    result = nil
    groups.each_with_index do |group, index|
      group_result = group.all? { |condition| crm_condition_matches?(condition) }
      operator = index.zero? ? 'AND' : condition_group_operator(index)
      result = result.nil? ? group_result : (operator.to_s.casecmp('OR').zero? ? result || group_result : result && group_result)
    end
    result == true
  end

  def grouped_conditions
    groups = @rule.condition_groups.presence
    return [@rule.conditions] if groups.blank?

    groups.map { |group| group['conditions'] || group[:conditions] || [] }
  end

  def condition_group_operator(index)
    group = @rule.condition_groups[index]
    group.with_indifferent_access.fetch(:operator, 'AND')
  end

  def crm_condition_matches?(condition)
    key = condition['attribute_key']
    operator = condition['filter_operator']
    values = Array(condition['values'])
    if operator == 'attribute_changed'
      attribute = CRM_ATTRIBUTES[key] || key.delete_prefix('crm_deal_').sub('_id', '_id')
      change = @options[:changed_attributes].to_h.with_indifferent_access[attribute]
      expected = condition['values'].is_a?(Hash) ? condition['values'].with_indifferent_access : {}
      return change.present? && Array(expected[:from]).map(&:to_s).include?(change[0].to_s) && Array(expected[:to]).map(&:to_s).include?(change[1].to_s)
    end
    values = custom_field_condition_values(values) if key.end_with?('custom_field')
    return @deal.present? if key == 'crm_deal_exists' && operator == 'is_present'
    return @deal.blank? if key == 'crm_deal_exists' && operator == 'is_not_present'

    actual = if CRM_ATTRIBUTES.key?(key)
               @deal&.public_send(CRM_ATTRIBUTES.fetch(key))
             elsif key == 'crm_deal_custom_field'
               custom_field_value(@deal, values.first, :deal)
             elsif key == 'crm_contact_custom_field'
               custom_field_value(@deal&.contact, values.first, :contact)
             end
    expected = key.end_with?('custom_field') ? values[1] : values.first
    compare_crm_value(actual, operator, expected)
  end

  def custom_field_value(record, key, type)
    return nil unless record && key.present?
    return record.custom_attributes[key] if type == :contact

    record.custom_field_values.includes(:custom_field).find { |value| value.custom_field.key == key }&.typed_value
  end

  def compare_crm_value(actual, operator, expected)
    case operator
    when 'equal_to' then actual.to_s.casecmp(expected.to_s).zero?
    when 'not_equal_to' then !actual.to_s.casecmp(expected.to_s).zero?
    when 'contains' then actual.to_s.downcase.include?(expected.to_s.downcase)
    when 'does_not_contain' then !actual.to_s.downcase.include?(expected.to_s.downcase)
    when 'is_present' then actual.present?
    when 'is_not_present' then actual.blank?
    when 'is_greater_than' then actual.to_f > expected.to_f
    when 'is_less_than' then actual.to_f < expected.to_f
    else false
    end
  end

  def rule_valid?
    is_valid = AutomationRules::ConditionValidationService.new(@rule).perform
    Rails.logger.info "Automation rule condition validation failed for rule id: #{@rule.id}" unless is_valid
    @rule.authorization_error! unless is_valid

    is_valid
  end

  def filter_operation(query_hash, current_index)
    if query_hash[:filter_operator] == 'starts_with'
      @filter_values["value_#{current_index}"] = "#{string_filter_values(query_hash)}%"
      like_filter_string(query_hash[:filter_operator], current_index)
    else
      super
    end
  end

  def apply_filter(query_hash, current_index)
    if crm_attribute?(query_hash['attribute_key'])
      @query_string += crm_query_string(query_hash.with_indifferent_access, current_index)
      return
    end

    conversation_filter = @conversation_filters[query_hash['attribute_key']]
    contact_filter = @contact_filters[query_hash['attribute_key']]
    message_filter = @message_filters[query_hash['attribute_key']]

    if query_hash['attribute_key'] == Captain::AutomationConditionService::ATTRIBUTE_KEY
      @query_string += captain_query_string(query_hash, current_index)
    elsif conversation_filter
      @query_string += conversation_query_string('conversations', conversation_filter, query_hash.with_indifferent_access, current_index)
    elsif contact_filter
      @query_string += contact_query_string(contact_filter, query_hash.with_indifferent_access, current_index)
    elsif message_filter
      @query_string += message_query_string(message_filter, query_hash.with_indifferent_access, current_index)
    elsif custom_attribute(query_hash['attribute_key'], @account, query_hash['custom_attribute_type'])
      # send table name according to attribute key right now we are supporting contact based custom attribute filter
      @query_string += custom_attribute_query(query_hash.with_indifferent_access, query_hash['custom_attribute_type'], current_index)
    end
  end

  def crm_attribute?(attribute_key)
    attribute_key == 'crm_deal_exists' || CRM_ATTRIBUTES.key?(attribute_key) ||
      %w[crm_deal_custom_field crm_contact_custom_field].include?(attribute_key)
  end

  def crm_query_string(query_hash, current_index)
    operator = query_hash[:query_operator]
    if query_hash[:attribute_key] == 'crm_deal_exists'
      exists = query_hash[:filter_operator] == 'is_not_present' ? 'NOT EXISTS' : 'EXISTS'
      return " #{exists} (#{crm_deal_subquery}) #{operator} "
    end

    if query_hash[:attribute_key].in?(%w[crm_deal_custom_field crm_contact_custom_field])
      field_values = custom_field_condition_values(query_hash[:values])
      key = field_values.first.to_s
      @filter_values["crm_field_key_#{current_index}"] = key
      value_filter = filter_operation({
        attribute_key: 'value', filter_operator: query_hash[:filter_operator], values: [field_values[1]]
      }.with_indifferent_access, current_index)
      if query_hash[:attribute_key] == 'crm_contact_custom_field'
        return " EXISTS (SELECT 1 FROM contacts contact_filter WHERE contact_filter.id = conversations.contact_id AND contact_filter.custom_attributes ->> :crm_field_key_#{current_index} #{value_filter}) #{operator} "
      end

      return " EXISTS (#{crm_deal_subquery} AND EXISTS (SELECT 1 FROM crm_deal_custom_field_values dcfv INNER JOIN crm_custom_fields dcf ON dcf.id = dcfv.custom_field_id WHERE dcfv.deal_id = d.id AND dcfv.account_id = #{@account.id} AND dcf.key = :crm_field_key_#{current_index} AND dcfv.value #{value_filter})) #{operator} "
    end

    column = CRM_ATTRIBUTES.fetch(query_hash[:attribute_key])
    value_filter = crm_filter_operation(query_hash, current_index)
    " EXISTS (#{crm_deal_subquery} AND d.#{column} #{value_filter}) #{operator} "
  end

  def crm_filter_operation(query_hash, current_index)
    if query_hash[:attribute_key] == 'crm_deal_value' &&
       query_hash[:filter_operator].in?(%w[is_greater_than is_less_than is_greater_than_or_equal_to is_less_than_or_equal_to])
      @filter_values["value_#{current_index}"] = BigDecimal(query_hash[:values].first.to_s)
      return {
        'is_greater_than' => '>', 'is_less_than' => '<',
        'is_greater_than_or_equal_to' => '>=', 'is_less_than_or_equal_to' => '<='
      }.fetch(query_hash[:filter_operator]) + " :value_#{current_index}"
    end

    filter_operation(query_hash, current_index)
  end

  def crm_deal_subquery
    "SELECT 1 FROM crm_deals d WHERE d.contact_id = conversations.contact_id AND d.account_id = #{@account.id}"
  end

  def custom_field_condition_values(values)
    values = Array(values)
    return values if values.length > 1

    values.first.to_s.split('=', 2).map(&:strip)
  end

  # If attribute_changed type filter is present perform this against array
  def perform_attribute_changed_filter(records)
    @attribute_changed_records = []
    current_attribute_changed_record = base_relation
    filter_based_on_attribute_change(records, current_attribute_changed_record)

    @attribute_changed_records.uniq
  end

  # Loop through attribute_changed_query_filter
  def filter_based_on_attribute_change(records, current_attribute_changed_record)
    @attribute_changed_query_filter.each do |filter|
      @changed_attributes = @changed_attributes.with_indifferent_access
      changed_attribute = @changed_attributes[filter['attribute_key']].presence

      if changed_attribute[0].in?(filter['values']['from']) && changed_attribute[1].in?(filter['values']['to'])
        @attribute_changed_records = attribute_changed_filter_query(filter, records, current_attribute_changed_record)
      end
      current_attribute_changed_record = @attribute_changed_records
    end
  end

  # We intersect with the record if query_operator-AND is present and union if query_operator-OR is present
  def attribute_changed_filter_query(filter, records, current_attribute_changed_record)
    if filter['query_operator'] == 'AND'
      @attribute_changed_records + (current_attribute_changed_record & records)
    else
      @attribute_changed_records + (current_attribute_changed_record | records)
    end
  end

  # Captain's answer is bound as a boolean so it takes part in the AND/OR chain like any SQL condition.
  def captain_query_string(query_hash, current_index)
    @filter_values["value_#{current_index}"] = @captain_answers[current_index]
    " :value_#{current_index} #{query_hash['query_operator']} "
  end

  def message_query_string(current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    attribute_key = 'processed_message_content' if attribute_key == 'content'
    attribute_key = 'private' if attribute_key == 'private_note'

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'standard'
      if current_filter['data_type'] == 'text'
        " LOWER(messages.#{attribute_key}) #{filter_operator_value} #{query_operator} "
      else
        " messages.#{attribute_key} #{filter_operator_value} #{query_operator} "
      end
    end
  end

  # This will be used in future for contact automation rule
  def contact_query_string(current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " contacts.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      " contacts.#{attribute_key} #{filter_operator_value} #{query_operator} "
    end
  end

  def conversation_query_string(table_name, current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    if attribute_key == 'assignee_id' && query_hash['filter_operator'].in?(%w[is_present is_not_present])
      return assignee_presence_filter(table_name, query_hash)
    end

    return " #{tag_filter_query(query_hash, current_index)} " if attribute_key == 'labels'

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " #{table_name}.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      " #{table_name}.#{attribute_key} #{filter_operator_value} #{query_operator} "
    end
  end

  private

  def captain_indexes
    @captain_indexes ||= @rule.conditions.each_index.select do |index|
      @rule.conditions[index]['attribute_key'] == Captain::AutomationConditionService::ATTRIBUTE_KEY
    end
  end

  def matches?(captain_answers)
    @captain_answers = captain_answers
    @query_string = ''
    @filter_values = {}
    @attribute_changed_query_filter = []

    return matches_condition_groups if @rule.condition_groups.present?

    @rule.conditions.each_with_index do |query_hash, current_index|
      @attribute_changed_query_filter << query_hash and next if query_hash['filter_operator'] == 'attribute_changed'

      apply_filter(query_hash, current_index)
    end

    records = base_relation.where(@query_string, @filter_values.with_indifferent_access)
    records = perform_attribute_changed_filter(records) if @attribute_changed_query_filter.any?

    records.any?
  end

  def matches_condition_groups
    result = nil
    @rule.condition_groups.each_with_index do |group, index|
      @query_string = ''
      @filter_values = {}
      Array(group['conditions'] || group[:conditions]).each_with_index do |query_hash, current_index|
        apply_filter(query_hash, current_index)
      end
      group_result = base_relation.where(@query_string, @filter_values.with_indifferent_access).any?
      operator = index.zero? ? 'AND' : group.with_indifferent_access.fetch(:operator, 'AND')
      result = result.nil? ? group_result : (operator.to_s.casecmp('OR').zero? ? result || group_result : result && group_result)
    end
    result == true
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def base_relation
    records = Conversation.where(id: @conversation.id).joins(
      'LEFT OUTER JOIN contacts on conversations.contact_id = contacts.id'
    ).joins(
      'LEFT OUTER JOIN messages on messages.conversation_id = conversations.id'
    )

    records = records.where(messages: { id: @options[:message].id }) if @options[:message].present?
    records
  end
end
