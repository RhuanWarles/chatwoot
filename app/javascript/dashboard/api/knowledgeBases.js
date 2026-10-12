import ApiClient from './ApiClient';

const client = new ApiClient('knowledge_bases', { accountScoped: true });
client.documents = id => axios.get(`${client.url}/${id}/documents`);
client.document = (id, documentId) =>
  axios.get(`${client.url}/${id}/documents/${documentId}`);
client.saveDocument = (id, data, documentId = null) =>
  documentId
    ? axios.patch(`${client.url}/${id}/documents/${documentId}`, data)
    : axios.post(`${client.url}/${id}/documents`, data);
client.deleteDocument = (id, documentId) =>
  axios.delete(`${client.url}/${id}/documents/${documentId}`);
client.reindex = (id, documentId) =>
  axios.post(`${client.url}/${id}/documents/${documentId}/reindex`);
client.search = (id, query) =>
  axios.post(`${client.url}/${id}/search`, { query });
export default client;
