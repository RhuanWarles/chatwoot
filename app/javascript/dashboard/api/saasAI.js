/* global axios */
import ApiClient from './ApiClient';

class SaasAI extends ApiClient {
  constructor() {
    super('saas_ai', { accountScoped: true });
  }

  save(settings) {
    return axios.patch(this.url, { settings });
  }

  call(data) {
    return axios.post(`${this.url}/calls`, data);
  }

  generate(data) {
    return axios.post(`${this.url}/text_generations`, data);
  }

  generation(id) {
    return axios.get(`${this.url}/text_generations/${id}`);
  }
}

export default new SaasAI();
