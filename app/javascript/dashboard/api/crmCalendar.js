/* global axios */
import ApiClient from './ApiClient';
class CrmCalendarAPI extends ApiClient {
  constructor() {
    super('crm/google_calendar', { accountScoped: true });
  }

  get(options = {}) {
    return axios.get(this.url, options);
  }

  disconnect() {
    return axios.delete(this.url);
  }
}
export default new CrmCalendarAPI();
