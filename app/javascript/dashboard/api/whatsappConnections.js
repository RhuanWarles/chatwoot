/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class WhatsappConnectionsAPI extends ApiClient {
  constructor() {
    super('whatsapp_connections', { accountScoped: true });
  }

  get(options = {}) {
    return axios.get(this.url, options);
  }

  show(id, options = {}) {
    return axios.get(`${this.url}/${id}`, options);
  }

  connect(id, regenerate = false) {
    return axios.post(`${this.url}/${id}/connect`, { regenerate });
  }

  disconnect(id) {
    return axios.post(`${this.url}/${id}/disconnect`);
  }
}

export default new WhatsappConnectionsAPI();
