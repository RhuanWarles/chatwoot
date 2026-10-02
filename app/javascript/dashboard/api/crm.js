/* global axios */
import ApiClient from './ApiClient';

class CrmAPI extends ApiClient {
  constructor(resource) {
    super(`crm/${resource}`, { accountScoped: true });
  }

  stages(pipelineId) {
    return new ApiClient(`crm/pipelines/${pipelineId}/stages`, { accountScoped: true });
  }

  reorderStages(pipelineId, stageIds) {
    return axios.patch(`${this.stages(pipelineId).url}/reorder`, { stage_ids: stageIds });
  }
}

export const pipelinesAPI = new CrmAPI('pipelines');
export const dealsAPI = new CrmAPI('deals');
export const stagesAPI = pipelineId => new CrmAPI(`pipelines/${pipelineId}/stages`);
