/* global axios */
import ApiClient from './ApiClient';

class AccountAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  get(accountId) {
    return accountId
      ? axios.get(`${this.apiVersion}/accounts/${accountId}`)
      : super.get();
  }

  createAccount(data) {
    return axios.post(`${this.apiVersion}/accounts`, data);
  }

  async getCacheKeys() {
    const response = await axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
    );
    return response.data.cache_keys;
  }

  uploadBrandingLogo(file) {
    const formData = new FormData();
    formData.append('branding_logo', file);
    return axios.post(
      `${this.apiVersion}/accounts/${this.accountIdFromRoute}/branding_logo`,
      formData
    );
  }

  deleteBrandingLogo() {
    return axios.delete(
      `${this.apiVersion}/accounts/${this.accountIdFromRoute}/branding_logo`
    );
  }
}

export default new AccountAPI();
