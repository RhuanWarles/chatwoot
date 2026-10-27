# Lets the AI that controls a lead card fill the custom fields of that lead from what the customer says in the conversation.
class Saas::AiAgents::LeadFields
  MULTISELECT_SEPARATOR = '|'.freeze

  def initialize(account, enabled:)
    @fields = enabled ? account.crm_custom_fields.where(active: true).order(:position, :id).to_a : []
  end

  def any?
    @fields.any?
  end

  def include?(key)
    @fields.any? { |field| field.key == key }
  end

  def instructions
    <<~TEXT
      Quando o cliente informar um dado que corresponda a um campo do lead (nome, interesse, segmento, orçamento etc.), \
      registre-o com #{Saas::AiAgents::BuiltinTools::UPDATE_FIELD}. Só preencha com informação dita claramente na conversa, \
      nunca por suposição, e não avise o cliente que o campo foi preenchido.
    TEXT
  end

  def description
    catalog = @fields.map { |field| "#{field.key} (#{field.name}): #{hint(field)}" }.join("\n")
    "Registra um dado do cliente num campo do lead. Campos disponíveis:\n#{catalog}"
  end

  def properties
    { 'field' => { 'type' => 'string', 'enum' => @fields.map(&:key) },
      'value' => { 'type' => 'string', 'description' => 'Valor a registrar, no formato indicado para o campo.' } }
  end

  def fill(deal, key, raw_value)
    field = @fields.find { |item| item.key == key }
    record = deal.custom_field_values.find_or_initialize_by(custom_field_id: field.id)
    previous = record.typed_value
    record.account_id = deal.account_id
    record.typed_value = input(field, raw_value)
    record.save!
    log_change(deal, field, previous, record.typed_value)
    "Campo #{field.name} registrado."
  end

  private

  def hint(field)
    case field.field_type
    when 'select' then "uma destas opções: #{field.options.join(', ')}"
    when 'multiselect' then "uma ou mais destas opções separadas por #{MULTISELECT_SEPARATOR}: #{field.options.join(', ')}"
    when 'number', 'currency' then 'número com ponto decimal, sem separador de milhar'
    when 'boolean' then 'true ou false'
    when 'date' then 'data no formato AAAA-MM-DD'
    when 'datetime' then 'data e hora no formato ISO 8601'
    else 'texto'
    end
  end

  def input(field, raw_value)
    text = raw_value.to_s.strip
    field.field_type == 'multiselect' ? text.split(MULTISELECT_SEPARATOR).map(&:strip).compact_blank : text
  end

  def log_change(deal, field, previous, current)
    return if previous == current

    deal.events.create!(
      account_id: deal.account_id, event_type: 'custom_field_changed',
      metadata: { field_name: field.name, field_key: field.key, field_type: field.field_type, from: previous, to: current }
    )
  end
end
