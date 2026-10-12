export const newAgent = () => ({
  name: '',
  description: '',
  provider: 'openai',
  model: '',
  temperature: 0.7,
  context_messages_limit: 20,
  system_prompt: '',
  inbox_ids: [],
  handoff_enabled: true,
  respond_to_groups: false,
  customer_memory_enabled: false,
  active: false,
  tool_ids: [],
  knowledge_base_ids: [],
});

export const agentPayload = agent => ({
  name: agent.name,
  description: agent.description,
  provider: agent.provider,
  model: agent.model,
  temperature: agent.temperature,
  context_messages_limit: agent.context_messages_limit ?? 20,
  system_prompt: agent.system_prompt,
  inbox_ids: [...agent.inbox_ids],
  handoff_enabled: agent.handoff_enabled,
  respond_to_groups: agent.respond_to_groups,
  customer_memory_enabled: agent.customer_memory_enabled,
  active: agent.active,
  tool_ids: [...(agent.tool_ids || (agent.tools || []).map(tool => tool.id))],
  knowledge_base_ids: [...(agent.knowledge_base_ids || (agent.knowledge_bases || []).map(base => base.id))],
});

export const validAgent = agent =>
  Boolean(
    agent.name.trim() &&
      agent.name.length <= 100 &&
      agent.model.trim() &&
      agent.model.length <= 100 &&
      agent.system_prompt.trim() &&
      agent.provider &&
      typeof agent.temperature === 'number' &&
      Number.isFinite(agent.temperature) &&
      agent.temperature >= 0 &&
      agent.temperature <= 1 &&
      Number.isInteger(agent.context_messages_limit) &&
      agent.context_messages_limit >= 1 &&
      agent.context_messages_limit <= 100
  );
