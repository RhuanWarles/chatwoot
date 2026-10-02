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
