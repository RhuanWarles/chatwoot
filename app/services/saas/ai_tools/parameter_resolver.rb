class Saas::AiTools::ParameterResolver
  SOURCES = %w[ai contact_phone contact_phone_e164 contact_name contact_email contact_id conversation_id account_id agent_id].freeze

  def initialize(tool:, account:, agent:, conversation: nil)
    @tool = tool
    @account = account
    @agent = agent
    @conversation = conversation
  end

  def call(arguments = {})
    args = arguments.stringify_keys
    @tool.parameters.each_with_object({}) do |parameter, resolved|
      name = parameter['name'].to_s
      source = parameter['value_source'].presence || 'ai'
      value = source == 'ai' ? args[name] : context[source]
      if value.nil?
        raise CustomExceptions::SaasError, "missing_context_value:#{name}" if parameter['required'] == true

        next
      end
      resolved[name] = value
    end
  end

  def context
    contact = @conversation&.contact
    phone = contact&.phone_number.to_s
    digits = phone.gsub(/\D/, '')
    {
      'contact_phone' => digits.presence,
      'contact_phone_e164' => digits.presence && "+#{digits}",
      'contact_name' => contact&.name.presence,
      'contact_email' => contact&.email.presence,
      'contact_id' => contact&.id,
      'conversation_id' => @conversation&.id,
      'account_id' => @account.id,
      'agent_id' => @agent.id
    }
  end
end
