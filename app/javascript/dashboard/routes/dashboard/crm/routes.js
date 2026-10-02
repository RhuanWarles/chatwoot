import { frontendURL } from '../../../helper/URLHelper';
import CrmDeals from './pages/CrmDeals.vue';
import CrmPipelines from './pages/CrmPipelines.vue';

const commonMeta = { permissions: ['administrator', 'agent'] };

export const routes = [
  { path: frontendURL('accounts/:accountId/crm/deals'), name: 'crm_deals', component: CrmDeals, meta: commonMeta },
  { path: frontendURL('accounts/:accountId/crm/pipelines'), name: 'crm_pipelines', component: CrmPipelines, meta: { permissions: ['administrator'] } },
];
