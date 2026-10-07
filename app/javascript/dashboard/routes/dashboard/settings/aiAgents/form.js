export const newAgent = () => ({
  name: '',
  description: '',
  provider: 'openai',
  model: '',
  temperature: 0.7,
  system_prompt: '',
  inbox_ids: [],
  handoff_enabled: true,
  active: false,
});

export const agentPayload = agent => ({
  name: agent.name,
  description: agent.description,
  provider: agent.provider,
  model: agent.model,
  temperature: agent.temperature,
  system_prompt: agent.system_prompt,
  inbox_ids: [...agent.inbox_ids],
  handoff_enabled: agent.handoff_enabled,
  active: agent.active,
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
      agent.temperature <= 1
  );
