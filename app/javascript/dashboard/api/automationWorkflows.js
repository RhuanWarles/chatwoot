/* global axios */
import ApiClient from './ApiClient';

class AutomationWorkflowsAPI extends ApiClient {
  constructor() {
    super('automation_workflows', { accountScoped: true });
  }

  run(workflowId, payload) {
    return axios.post(`${this.url}/${workflowId}/run`, payload);
  }

  runs(workflowId) {
    return axios.get(`${this.url}/${workflowId}/runs`);
  }
}

// The loss reasons registry belongs to the CRM; the builder only reads it.
export const workflowLostReasonsAPI = new ApiClient('crm/lost_reasons', {
  accountScoped: true,
});

export default new AutomationWorkflowsAPI();
