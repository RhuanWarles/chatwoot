class Saas::AiTool < ApplicationRecord
  self.table_name = 'saas_ai_tools'

  METHODS = %w[GET POST PUT PATCH DELETE].freeze
  PARAMETER_TYPES = %w[string number integer boolean enum].freeze
  TOOL_TYPES = %w[http].freeze

  belongs_to :account
  has_many :ai_tool_agents, class_name: 'Saas::AiToolAgent', dependent: :destroy
  has_many :agents, through: :ai_tool_agents, source: :ai_agent
  has_many :executions, class_name: 'Saas::AiToolExecution', foreign_key: :ai_tool_id, dependent: :delete_all, inverse_of: :ai_tool
  encrypts :secret_headers if Chatwoot.encryption_configured?

  validates :name, :slug, :description, :tool_type, presence: true
  validates :name, length: { maximum: 100 }
  validates :slug, format: { with: /\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*\z/ }, length: { maximum: 64 }, uniqueness: { scope: :account_id }
  # Only when the slug is set or changed, so a tool saved before this rule existed stays editable.
  validates :slug, exclusion: { in: Saas::AiAgents::BuiltinTools::NAMES }, if: :will_save_change_to_slug?
  validates :tool_type, inclusion: { in: TOOL_TYPES }
  validate :valid_configuration
  validate :secrets_require_encryption
  before_validation :generate_slug, on: :create

  def parameters
    Array(configuration['parameters']).map { |item| item.stringify_keys }
  end

  def function_definition
    { type: 'function', function: { name: slug, description: description, parameters: json_schema } }
  end

  def json_schema
    properties = {}
    required = []
    parameters.each do |parameter|
      next unless parameter['name'].to_s.match?(/\A[a-zA-Z][a-zA-Z0-9_]*\z/)
      next unless parameter['value_source'].to_s.presence.in?([nil, 'ai'])

      schema = { 'type' => parameter['type'] == 'enum' ? 'string' : parameter['type'].to_s,
                 'description' => parameter['description'].to_s }
      schema['enum'] = Array(parameter['enum_values']).map(&:to_s) if parameter['type'] == 'enum'
      properties[parameter['name']] = schema
      required << parameter['name'] if parameter['required'] == true
    end
    { 'type' => 'object', 'properties' => properties, 'required' => required, 'additionalProperties' => false }
  end

  def public_data
    { 'id' => id, 'name' => name, 'slug' => slug, 'description' => description, 'tool_type' => tool_type,
      'active' => active, 'allow_in_playground' => allow_in_playground,
      'configuration' => configuration.except('secret_headers').merge('secret_headers_configured' => secret_headers.present?,
                                                                        'secret_header_names' => secret_header_names) }
  end

  def secret_header_names
    return [] if secret_headers.blank?

    value = secret_headers.is_a?(String) ? JSON.parse(secret_headers) : secret_headers
    value.to_h.keys
  rescue JSON::ParserError
    []
  end

  private

  def generate_slug
    return if slug.present?

    self.slug = I18n.transliterate(name.to_s)
                      .downcase
                      .gsub(/[^a-z0-9]+/, '_')
                      .gsub(/_+/, '_')
                      .sub(/\A_+/, '')
                      .sub(/_+\z/, '')
  end

  def valid_configuration
    return unless tool_type == 'http'

    config = configuration.stringify_keys
    errors.add(:configuration, :invalid) unless METHODS.include?(config['method']) && config['url'].to_s.start_with?('http://', 'https://')
    timeout = config['timeout_seconds'].to_i
    errors.add(:configuration, :invalid) unless timeout.between?(1, 30)
    names = []
    parameters.each do |parameter|
      valid_name = parameter['name'].to_s.match?(/\A[a-zA-Z][a-zA-Z0-9_]*\z/)
      source = parameter['value_source'].to_s.presence || 'ai'
      errors.add(:configuration, :invalid) unless PARAMETER_TYPES.include?(parameter['type']) && valid_name && Saas::AiTools::ParameterResolver::SOURCES.include?(source)
      errors.add(:configuration, :invalid) if names.include?(parameter['name'].to_s)
      names << parameter['name'].to_s
    end
  end

  def secrets_require_encryption
    errors.add(:secret_headers, :invalid) if secret_headers.present? && !Chatwoot.encryption_configured?
  end
end
