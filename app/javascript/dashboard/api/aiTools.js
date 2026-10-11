import ApiClient from './ApiClient';

const client = new ApiClient('ai_tools', { accountScoped: true });

client.test = (id, agentId, argumentsPayload = {}) =>
  axios.post(`${client.url}/${id}/test`, {
    agent_id: agentId,
    arguments: argumentsPayload,
  });

export default client;
