/* global axios */
import ApiClient from './ApiClient';

const client = new ApiClient('general_dashboard', { accountScoped: true });

client.show = params => axios.get(client.url, { params });

export default client;
