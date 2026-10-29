module AutomationRules
  class VariableResolver
    TOKEN = /\{\{\s*([^}]+?)\s*\}\}/.freeze

    def initialize(context)
      @context = context
    end

    def resolve(value)
      case value
      when String
        value.gsub(TOKEN) { lookup(Regexp.last_match(1)) }
      when Array
        value.map { |item| resolve(item) }
      when Hash
        value.to_h { |key, item| [key, resolve(item)] }
      else
        value
      end
    end

    private

    def lookup(path)
      key = path.to_s.strip
      return @context.variables[key] if @context.variables.key?(key)

      object, attribute = key.split('.', 2)
      value = case object
              when 'contact' then read(@context.contact, attribute)
              when 'conversation' then read(@context.conversation, attribute)
              when 'inbox' then read(@context.inbox, attribute)
              when 'assignee' then read(@context.assignee, attribute)
              when 'team' then read(@context.team, attribute)
              when 'deal' then read(@context.deal, attribute)
              when 'trigger' then read(@context.trigger, attribute)
              when 'change' then read(@context.event_changes, attribute)
              else nil
              end
      value.nil? ? '' : value.to_s
    end

    def read(object, attribute)
      return nil if object.nil? || attribute.blank?
      if object.is_a?(Hash)
        parts = attribute.split('.')
        if parts.length == 2 && object[parts.first].is_a?(Array) && %w[from to].include?(parts.last)
          return object[parts.first][parts.last == 'from' ? 0 : 1]
        end
        value = attribute.split('.').reduce(object) { |current, key| current.is_a?(Hash) ? (current[key] || current[key.to_sym]) : nil }
        return value unless value.nil?
      end

      if object.is_a?(Hash) && object[attribute].is_a?(Array)
        return object[attribute]
      end

      if attribute.start_with?('custom_fields.')
        key = attribute.delete_prefix('custom_fields.')
        return object.custom_attributes[key] if object.respond_to?(:custom_attributes)
        return object.custom_field_values.joins(:custom_field).find_by(crm_custom_fields: { key: key })&.typed_value if object.respond_to?(:custom_field_values)
      end

      if attribute.start_with?('custom_attributes.') && object.respond_to?(:custom_attributes)
        return object.custom_attributes[attribute.delete_prefix('custom_attributes.')]
      end

      return object.last_relevant_message&.content if object == @context.conversation && attribute == 'last_message'
      return object.pipeline&.name if object.respond_to?(:pipeline) && attribute == 'pipeline'
      return object.pipeline_stage&.name if object.respond_to?(:pipeline_stage) && attribute == 'stage'

      object.public_send(attribute) if object.respond_to?(attribute)
    end
  end
end
