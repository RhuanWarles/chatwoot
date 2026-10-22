class Saas::AiAgents::BuiltinTools
  HANDOFF = 'handoff_to_human'.freeze
  MOVE_STAGE = 'move_lead_stage'.freeze
  NAMES = [HANDOFF, MOVE_STAGE].freeze

  def initialize(agent:, conversation:)
    @agent = agent
    @conversation = conversation
    @handed_off = false
  end

  def handed_off?
    @handed_off
  end

  def definitions
    [handoff_definition, move_stage_definition].compact
  end

  def instructions
    parts = []
    parts << <<~TEXT if @agent.handoff_enabled?
      Se você não souber responder com segurança, não tiver a informação na sua base, o cliente pedir para falar com uma pessoa, \
      reclamar ou o assunto exigir decisão humana, chame a ferramenta #{HANDOFF} e depois avise o cliente, de forma breve, \
      que um atendente humano continuará a conversa. Nunca invente respostas.
    TEXT
    parts << <<~TEXT if stages.present?
      Você também controla o card (lead) deste cliente no funil. Conforme a conversa avançar, chame #{MOVE_STAGE} \
      para mover o lead para a etapa que melhor representa o momento atual. Só mova quando houver evidência clara na conversa, \
      não avise o cliente sobre a movimentação.
    TEXT
    parts.join("\n").presence
  end

  def call(name, arguments)
    reason = arguments['reason'].to_s.strip.first(500)
    result = name == HANDOFF ? handoff(reason) : move_stage(arguments['stage'].to_s, reason)
    { 'success' => true, 'result' => result }
  rescue ActiveRecord::RecordInvalid => e
    { 'success' => false, 'error' => e.message }
  end

  private

  def handoff_definition
    return unless @agent.handoff_enabled?

    function(HANDOFF, 'Transfere a conversa para um atendente humano e pausa a IA nesta conversa.',
             { 'reason' => { 'type' => 'string', 'description' => 'Motivo curto da transferência.' } }, ['reason'])
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

  def handoff(reason)
    @conversation.with_lock do
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        Saas::AiAgents::Runtime::STATE_KEY => 'human', 'ai_agent_paused_at' => Time.current.iso8601, 'ai_agent_handoff_reason' => reason
      ))
    end
    @conversation.bot_handoff!
    Messages::MessageBuilder.new(@agent, @conversation, {
                                   content: "IA transferiu para atendimento humano. Motivo: #{reason}",
                                   message_type: 'outgoing', private: true
                                 }).perform
    @handed_off = true
    'Transferência registrada. Avise o cliente brevemente que um atendente humano vai continuar o atendimento.'
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
    @open_deal ||= @conversation.account.crm_deals.where(contact_id: @conversation.contact_id, status: 'open').order(updated_at: :desc).first
  end

  def create_deal(stage)
    @conversation.account.crm_deals.create!(name: @conversation.contact.name.presence || "Lead ##{@conversation.contact_id}",
                                            contact: @conversation.contact, pipeline: pipeline, pipeline_stage: stage)
  end

  def pipeline
    @pipeline ||= open_deal&.pipeline || @conversation.account.crm_pipelines.active.joins(:stages).order(:id).first
  end

  def stages
    return [] unless @agent.crm_stage_automation_enabled? && @conversation.contact_id && pipeline

    @stages ||= pipeline.stages.to_a
  end
end
