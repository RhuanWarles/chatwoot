/* global axios */
import ApiClient from './ApiClient';

class CrmAPI extends ApiClient {
  constructor(resource) {
    super(`crm/${resource}`, { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  stages(pipelineId) {
    return new ApiClient(`crm/pipelines/${pipelineId}/stages`, {
      accountScoped: true,
    });
  }

  show(id, options = {}) {
    return axios.get(`${this.url}/${id}`, options);
  }

  events(dealId, page = 1, options = {}) {
    return axios.get(`${this.url}/${dealId}/events`, {
      ...options,
      params: { page },
    });
  }

  addNote(dealId, body) {
    return axios.post(`${this.url}/${dealId}/events`, { event: { body } });
  }

  // eslint-disable-next-line class-methods-use-this
  activities(dealId) {
    return new ApiClient(`crm/deals/${dealId}/activities`, {
      accountScoped: true,
    });
  }

  updateNote(dealId, id, body) {
    return axios.patch(`${this.url}/${dealId}/events/${id}`, {
      event: { body },
    });
  }

  deleteNote(dealId, id) {
    return axios.delete(`${this.url}/${dealId}/events/${id}`);
  }

  reorderStages(pipelineId, stageIds) {
    return axios.patch(`${this.stages(pipelineId).url}/reorder`, {
      stage_ids: stageIds,
    });
  }
}

export const pipelinesAPI = new CrmAPI('pipelines');
export const dealsAPI = new CrmAPI('deals');
export const stagesAPI = pipelineId =>
  new CrmAPI(`pipelines/${pipelineId}/stages`);
