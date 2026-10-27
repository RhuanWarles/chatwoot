class Saas::AiAgents::BuiltinTools
  HANDOFF = 'handoff_to_human'.freeze
  MOVE_STAGE = 'move_lead_stage'.freeze
  UPDATE_FIELD = 'update_lead_field'.freeze
  NAMES = [HANDOFF, MOVE_STAGE, UPDATE_FIELD].freeze
  HANDOFF_NOTE_LIMIT = 250
  HANDOFF_NOTE_PREFIX = 'Transferido pela IA. Resumo: '.freeze
  HANDOFF_NOTE_WITHOUT_SUMMARY = 'Transferido pela IA. Resumo não informado.'.freeze
  HANDOFF_MARKER_KEY = 'ai_handoff'.freeze
  HANDOFF_SUMMARY_HELP = 'Resumo fiel do que foi conversado, em português, com no máximo 200 caracteres: o que o cliente quer, ' \
                         'o que já foi respondido e o que falta resolver. Sem dados sensíveis.'.freeze

  def initialize(agent:, conversation:)
    @agent = agent
    @conversation = conversation
    @handed_off = false
  end

  def handed_off?
    @handed_off
  end

  def definitions
    [handoff_definition, move_stage_definition, update_field_definition].compact
  end

  def instructions
    parts = []
    parts << <<~TEXT if @agent.handoff_enabled?
      Se você não souber responder com segurança, não tiver a informação na sua base, o cliente pedir para falar com uma pessoa, \
      reclamar ou o assunto exigir decisão humana, chame a ferramenta #{HANDOFF} e depois avise o cliente, de forma breve, \
      que o atendimento humano foi solicitado. Nunca invente respostas.

      Ao chamar #{HANDOFF}, preencha summary com um resumo fiel da conversa para o atendente humano: o que o cliente quer, \
      o que você já respondeu e o que ainda falta resolver. Escreva em português, em 1 ou 2 frases curtas \
      (máximo de 200 caracteres), sem dados sensíveis como senhas, números de cartão ou documentos. \
      O resumo vai para uma nota interna: não o repita para o cliente.
    TEXT
    if handoff_conditions?
      parts << "Transfira também para um atendente humano nas situações definidas pela empresa:\n#{@agent.handoff_conditions.strip}\n"
    end
    parts << <<~TEXT if stages.present?
      Você também controla o card (lead) deste cliente no funil. Conforme a conversa avançar, chame #{MOVE_STAGE} \
      para mover o lead para a etapa que melhor representa o momento atual. Só mova quando houver evidência clara na conversa, \
      não avise o cliente sobre a movimentação.
    TEXT
    parts << lead_fields.instructions if lead_fields.any?
    parts.join("\n").presence
  end

  def call(name, arguments)
    { 'success' => true, 'result' => run_tool(name, arguments) }
  rescue ActiveRecord::RecordInvalid => e
    { 'success' => false, 'error' => e.message }
  end

  private

  def run_tool(name, arguments)
    case name
    when HANDOFF then handoff(arguments['summary'])
    when UPDATE_FIELD then fill_field(arguments['field'].to_s, arguments['value'])
    else move_stage(arguments['stage'].to_s, arguments['reason'].to_s.strip.first(500))
    end
  end

  def fill_field(key, value)
    return 'Campo inválido.' unless lead_fields.include?(key)

    lead_fields.fill(open_deal || create_deal(stages.first), key, value)
  end

  def update_field_definition
    return unless lead_fields.any?

    function(UPDATE_FIELD, lead_fields.description, lead_fields.properties, %w[field value])
  end

  # Only the AI that controls the lead card can fill its fields.
  def lead_fields
    @lead_fields ||= Saas::AiAgents::LeadFields.new(@conversation.account, enabled: stages.present?)
  end

  def handoff_conditions?
    @agent.handoff_enabled? && @agent.handoff_conditions.present?
  end

  def handoff_definition
    return unless @agent.handoff_enabled?

    function(HANDOFF, 'Sinaliza a necessidade de atendimento humano e deixa uma nota interna com o resumo da conversa.',
             { 'summary' => { 'type' => 'string', 'description' => HANDOFF_SUMMARY_HELP } }, ['summary'])
  end

  def move_stage_definition
    return if stages.blank?

    catalog = stages.map { |stage| [stage.name, stage.ai_instructions.presence].compact.join(': ') }.join("\n")
    function(MOVE_STAGE, "Move o lead deste cliente para outra etapa do funil '#{pipeline.name}'. Etapas disponíveis:\n#{catalog}",
             { 'stage' => { 'type' => 'string', 'enum' => stages.map(&:name) },
               'reason' => { 'type' => 'string', 'description' => 'Motivo curto baseado na conversa.' } }, %w[stage reason])
  end

  def function(name, description, properties, required)
    { type: 'function', function: { name: name, description: description,
                                    parameters: { 'type' => 'object', 'properties' => properties, 'required' => required,
                                                  'additionalProperties' => false } } }
  end

  def handoff(summary)
    return 'Transferência já registrada.' if @handed_off

    @conversation.with_lock do
      attributes = @conversation.additional_attributes.merge(
        Saas::AiAgents::Runtime::STATE_KEY => 'active', HANDOFF_MARKER_KEY => true, 'ai_handoff_at' => Time.current.iso8601
      )
      attributes.delete('ai_agent_paused_at')
      attributes.delete('ai_agent_paused_by_id')
      @conversation.update!(additional_attributes: attributes)
      Messages::MessageBuilder.new(@agent, @conversation, {
                                     content: handoff_note(summary), message_type: 'outgoing', private: true,
                                     content_attributes: { 'ai_agent_id' => @agent.id, 'ai_handoff' => true }
                                   }).perform
    end
    @handed_off = true
    @conversation.bot_handoff!
    'Atendimento humano solicitado. Avise o cliente brevemente que o atendimento humano foi solicitado.'
  rescue ActiveRecord::RecordInvalid
    # The rolled-back update! still holds its attributes in memory, which would make the next with_lock raise.
    @conversation.reload
    raise
  end

  def handoff_note(summary)
    text = summary.is_a?(String) ? summary.scrub : ''
    text = text.gsub('mention://', '') while text.include?('mention://')
    text = text.gsub(/[[:cntrl:]]/, ' ').squish
    return HANDOFF_NOTE_WITHOUT_SUMMARY if text.blank?

    "#{HANDOFF_NOTE_PREFIX}#{fit(text, HANDOFF_NOTE_LIMIT - HANDOFF_NOTE_PREFIX.length)}"
  end

  # Never exceeds `limit` characters and never splits a grapheme cluster (emoji, ZWJ sequences, accents); prefers a word boundary.
  def fit(text, limit)
    return text if text.length <= limit

    total = 0
    kept = text.each_grapheme_cluster.take_while { |cluster| (total += cluster.length) <= limit - 1 }.join
    kept = kept.sub(/\s+\S*\z/, '') unless text[kept.length].match?(/\s/)
    "#{kept.rstrip}…"
  end

  def move_stage(stage_name, reason)
    stage = stages.find { |item| item.name == stage_name }
    return 'Etapa inválida.' unless stage

    deal = open_deal || create_deal(stage)
    return "O lead já está na etapa #{stage.name}." if deal.pipeline_stage_id == stage.id && !deal.previously_new_record?

    deal.update!(pipeline_stage: stage) unless deal.pipeline_stage_id == stage.id
    deal.events.create!(
      account_id: deal.account_id, event_type: 'note_created',
      metadata: { body: "IA moveu o lead para #{stage.name}. #{reason}".strip }
    )
    "Lead movido para #{stage.name}."
  end

  def open_deal
    @open_deal ||= begin
      deals = @conversation.account.crm_deals.where(contact_id: @conversation.contact_id, status: 'open')
      # With a pipeline chosen on the agent, only cards inside it are the AI's to move.
      deals = deals.where(pipeline_id: @agent.crm_pipeline_id) if @agent.crm_pipeline_id
      deals.order(updated_at: :desc).first
    end
  end

  def create_deal(stage)
    @conversation.account.crm_deals.create!(name: @conversation.contact.name.presence || "Lead ##{@conversation.contact_id}",
                                            contact: @conversation.contact, pipeline: pipeline, pipeline_stage: stage)
  end

  # The pipeline chosen on the agent wins; if it was deactivated the tool is withheld rather than falling back to another pipeline.
  def pipeline
    return @pipeline if defined?(@pipeline)

    @pipeline = if @agent.crm_pipeline_id
                  @agent.crm_pipeline if @agent.crm_pipeline&.active?
                else
                  open_deal&.pipeline || @conversation.account.crm_pipelines.active.joins(:stages).order(:id).first
                end
  end

  def stages
    return [] unless @agent.crm_stage_automation_enabled? && @conversation.contact_id && pipeline

    @stages ||= pipeline.stages.to_a
  end
end
