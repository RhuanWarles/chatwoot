import ApiClient from './ApiClient';

const client = new ApiClient('ai_tools', { accountScoped: true });

client.test = (id, agentId, argumentsPayload = {}, conversationId = null) =>
  axios.post(`${client.url}/${id}/test`, {
    agent_id: agentId,
    arguments: argumentsPayload,
    conversation_id: conversationId,
  });

client.executions = params => axios.get(`${client.url.replace('/ai_tools', '')}/ai_tool_executions`, { params });
client.execution = id => axios.get(`${client.url.replace('/ai_tools', '')}/ai_tool_executions/${id}`);

export default client;
