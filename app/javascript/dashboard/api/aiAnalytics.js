/* global axios */
import ApiClient from './ApiClient';

const client = new ApiClient('ai_analytics', { accountScoped: true });

client.show = params => axios.get(client.url, { params });
client.replies = params => axios.get(`${client.url}/replies`, { params });

export default client;
