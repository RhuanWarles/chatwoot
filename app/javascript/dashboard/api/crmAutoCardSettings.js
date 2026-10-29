/* global axios */
import ApiClient from './ApiClient';

// Where the cards that are created for every new lead land (administrators only).
class CrmAutoCardSettingsAPI extends ApiClient {
  constructor() {
    super('crm/auto_card_settings', { accountScoped: true });
  }

  getSettings() {
    return axios.get(this.url);
  }

  updateSettings(settings) {
    return axios.patch(this.url, { auto_card_settings: settings });
  }
}

export default new CrmAutoCardSettingsAPI();
