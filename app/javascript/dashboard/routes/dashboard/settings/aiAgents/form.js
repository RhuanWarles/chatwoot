export const HANDOFF_CONDITIONS_MAX_LENGTH = 1000;
export const DEFAULT_TIMEZONE = 'America/Sao_Paulo';

export const newAgent = () => ({
  name: '',
  description: '',
  provider: 'openai',
  model: '',
  timezone: DEFAULT_TIMEZONE,
  temperature: 0.7,
  context_messages_limit: 20,
  response_delay_seconds: 2,
  split_response_messages: true,
  system_prompt: '',
  inbox_ids: [],
  handoff_enabled: true,
  handoff_conditions: '',
  crm_stage_automation_enabled: false,
  crm_pipeline_id: null,
  respond_to_groups: false,
  customer_memory_enabled: false,
  audio_enabled: false,
  attachment_interpretation_enabled: false,
  active: false,
  tool_ids: [],
  knowledge_base_ids: [],
});

export const agentPayload = agent => ({
  name: agent.name,
  description: agent.description,
  provider: agent.provider,
  model: agent.model,
  timezone: agent.timezone?.trim() || DEFAULT_TIMEZONE,
  temperature: agent.temperature,
  context_messages_limit: agent.context_messages_limit ?? 20,
  response_delay_seconds: agent.response_delay_seconds ?? 2,
  split_response_messages: agent.split_response_messages ?? true,
  system_prompt: agent.system_prompt,
  inbox_ids: [...agent.inbox_ids],
  handoff_enabled: agent.handoff_enabled,
  handoff_conditions: agent.handoff_conditions?.trim() || null,
  crm_stage_automation_enabled: agent.crm_stage_automation_enabled ?? false,
  crm_pipeline_id: agent.crm_pipeline_id || null,
  respond_to_groups: agent.respond_to_groups,
  customer_memory_enabled: agent.customer_memory_enabled,
  audio_enabled: agent.audio_enabled === true,
  attachment_interpretation_enabled:
    agent.attachment_interpretation_enabled === true,
  active: agent.active,
  tool_ids: [...(agent.tool_ids || (agent.tools || []).map(tool => tool.id))],
  knowledge_base_ids: [
    ...(agent.knowledge_base_ids ||
      (agent.knowledge_bases || []).map(base => base.id)),
  ],
});

export const validAgent = agent =>
  Boolean(
    agent.name.trim() &&
      agent.name.length <= 100 &&
      agent.model.trim() &&
      agent.model.length <= 100 &&
      typeof agent.timezone === 'string' &&
      agent.timezone.trim().length > 0 &&
      agent.system_prompt.trim() &&
      agent.provider &&
      typeof agent.temperature === 'number' &&
      Number.isFinite(agent.temperature) &&
      agent.temperature >= 0 &&
      agent.temperature <= 1 &&
      Number.isInteger(agent.context_messages_limit) &&
      agent.context_messages_limit >= 1 &&
      agent.context_messages_limit <= 100 &&
      Number.isInteger(agent.response_delay_seconds) &&
      agent.response_delay_seconds >= 0 &&
      agent.response_delay_seconds <= 10 &&
      typeof agent.split_response_messages === 'boolean' &&
      (agent.handoff_conditions || '').length <= HANDOFF_CONDITIONS_MAX_LENGTH
  );
