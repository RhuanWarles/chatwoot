/* global axios */
import ApiClient from './ApiClient';

class CsNotesAPI extends ApiClient {
  constructor() {
    super('cs_note_settings', { accountScoped: true });
  }

  // Whether the person can see the CS notes, the fields, and for administrators the team in charge.
  getSettings() {
    return axios.get(this.url);
  }

  updateSettings(teamId) {
    return axios.patch(this.url, { team_id: teamId });
  }

  createField(field) {
    return axios.post(`${this.baseUrl()}/cs_note_fields`, {
      cs_note_field: field,
    });
  }

  updateField(id, field) {
    return axios.patch(`${this.baseUrl()}/cs_note_fields/${id}`, {
      cs_note_field: field,
    });
  }

  deleteField(id) {
    return axios.delete(`${this.baseUrl()}/cs_note_fields/${id}`);
  }

  getValues(contactId) {
    return axios.get(`${this.baseUrl()}/contacts/${contactId}/cs_note`);
  }

  // Only the fields sent are changed; an empty value clears the field.
  saveValues(contactId, fieldValues) {
    return axios.patch(`${this.baseUrl()}/contacts/${contactId}/cs_note`, {
      field_values: fieldValues,
    });
  }
}

export default new CsNotesAPI();
