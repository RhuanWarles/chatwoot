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
client.memories = agentId => axios.get(`${client.url}/${agentId}/memories`);
client.clearMemory = (agentId, contactId) =>
  axios.delete(`${client.url}/${agentId}/memories/${contactId}`);
client.tools = () => axios.get(`${client.url.replace('/ai_agents', '/ai_tools')}`);
client.createTool = payload => axios.post(`${client.url.replace('/ai_agents', '/ai_tools')}`, payload);
client.updateTool = (id, payload) => axios.patch(`${client.url.replace('/ai_agents', '/ai_tools')}/${id}`, payload);
client.deleteTool = id => axios.delete(`${client.url.replace('/ai_agents', '/ai_tools')}/${id}`);
client.testTool = (id, agentId, argumentsPayload) =>
  axios.post(`${client.url.replace('/ai_agents', '/ai_tools')}/${id}/test`, { agent_id: agentId, arguments: argumentsPayload });

export default client;
