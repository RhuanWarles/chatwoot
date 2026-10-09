export const newVoiceAgent = () => ({
  name: '',
  description: '',
  provider: 'vapi',
  assistant_id: '',
  phone_number_id: '',
  active: false,
  inbound_enabled: false,
  outbound_enabled: false,
  max_call_duration: null,
});

export const voiceAgentPayload = agent =>
  Object.fromEntries(
    Object.keys(newVoiceAgent()).map(key => [key, agent[key]])
  );

export const validVoiceAgent = (agent, providers, durationRange) =>
  Boolean(
    agent.name.trim() &&
      agent.name.length <= 100 &&
      providers.includes(agent.provider) &&
      agent.assistant_id.length <= 100 &&
      agent.phone_number_id.length <= 100 &&
      (agent.max_call_duration === null ||
        (Number.isInteger(agent.max_call_duration) &&
          agent.max_call_duration >= durationRange[0] &&
          agent.max_call_duration <= durationRange[1]))
  );
