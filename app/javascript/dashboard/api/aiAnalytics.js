import ApiClient from './ApiClient';

const client = new ApiClient('ai_analytics', { accountScoped: true });

client.show = params => axios.get(client.url, { params });

export default client;
