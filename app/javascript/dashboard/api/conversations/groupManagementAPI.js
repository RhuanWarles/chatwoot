/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class GroupManagementAPI extends ApiClient {
  constructor(conversationId) {
    super(`conversations/${conversationId}/group`, { accountScoped: true });
  }

  update(body) {
    return axios.patch(this.url, body);
  }

  participants(body) {
    return axios.post(`${this.url}/participants`, body);
  }

  leave() {
    return axios.post(`${this.url}/leave`, { confirmed: true });
  }
}

export default conversationId => new GroupManagementAPI(conversationId);
