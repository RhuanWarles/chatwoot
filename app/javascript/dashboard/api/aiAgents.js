import ApiClient from './ApiClient';

const client = new ApiClient('ai_agents', { accountScoped: true });

client.playgroundSession = (agentId, sessionId) =>
  axios.get(`${client.url}/${agentId}/playground/${sessionId}`);
client.sendPlaygroundMessage = (agentId, sessionId, payload) =>
  axios.post(`${client.url}/${agentId}/playground/messages`, {
    ...payload,
    session_id: sessionId,
  });
client.clearPlaygroundSession = (agentId, sessionId) =>
  axios.delete(`${client.url}/${agentId}/playground/${sessionId}`);

export default client;
