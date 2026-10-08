import ApiClient from 'dashboard/api/ApiClient';

class WhatsappGroupsAPI extends ApiClient {
  constructor() {
    super('whatsapp_groups', { accountScoped: true });
  }
}

export default new WhatsappGroupsAPI();
