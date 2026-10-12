import ApiClient from './ApiClient';

const client = new ApiClient('conversations', { accountScoped: true });

client.index = conversationId =>
  axios.get(`${client.url}/${conversationId}/knowledge_retrievals`);

client.show = (conversationId, id) =>
  axios.get(`${client.url}/${conversationId}/knowledge_retrievals/${id}`);

export default client;
