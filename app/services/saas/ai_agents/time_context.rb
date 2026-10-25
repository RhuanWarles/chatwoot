class Saas::AiAgents::TimeContext
  HEADER = 'Data e hora atuais:'.freeze
  LEGACY_NOW_TEMPLATE = /\{\{\s*["']now["']\s*\|\s*date\s*:\s*["']([^"']+)["']\s*\}\}/i
  RELATIVE_DATE_GUIDANCE = 'Interprete hoje, ontem, anteontem e períodos relativos com base nesta referência temporal.'.freeze

  def self.for_agent(agent, now: Time.current)
    timezone = agent.respond_to?(:timezone) ? agent.timezone : nil
    message(timezone, now: now)
  end

  def self.message(timezone, now: Time.current)
    timezone = timezone.presence || Saas::AiAgent::DEFAULT_TIMEZONE
    local_time = now.in_time_zone(timezone)
    "#{HEADER} #{local_time.iso8601}\nFuso horário do assistente: #{timezone}\n#{RELATIVE_DATE_GUIDANCE}"
  end

  def self.refresh!(messages, timezone, now: Time.current)
    return messages if timezone.blank?

    replacement = { role: 'system', content: message(timezone, now: now) }
    indexes = messages.each_index.select { |index| time_context_message?(messages[index]) }
    if indexes.empty?
      system_index = messages.index do |item|
        next false unless item.is_a?(Hash)

        item[:role].to_s == 'system' || item['role'].to_s == 'system'
      end
      messages.insert((system_index || -1) + 1, replacement)
    else
      first_index = indexes.first
      indexes.reverse_each { |index| messages.delete_at(index) }
      messages.insert(first_index, replacement)
    end
    messages
  end

  def self.render_legacy_now(prompt, timezone, now: Time.current)
    local_time = now.in_time_zone(timezone.presence || Saas::AiAgent::DEFAULT_TIMEZONE)
    prompt.to_s.gsub(LEGACY_NOW_TEMPLATE) do
      local_time.strftime(Regexp.last_match(1))
    rescue ArgumentError
      local_time.iso8601
    end
  end

  def self.time_context_message?(message)
    return false unless message.is_a?(Hash)

    message[:content].to_s.start_with?(HEADER) || message['content'].to_s.start_with?(HEADER)
  end
  private_class_method :time_context_message?
end
