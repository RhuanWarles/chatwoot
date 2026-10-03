import { frontendURL } from '../../../helper/URLHelper';
import CrmDealDetails from './pages/CrmDealDetails.vue';
import CrmDeals from './pages/CrmDeals.vue';
import CrmPipelines from './pages/CrmPipelines.vue';
import CrmCustomFields from './pages/CrmCustomFields.vue';

const commonMeta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm/deals/:dealId'),
    name: 'crm_deal_details',
    component: CrmDealDetails,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/deals'),
    name: 'crm_deals',
    component: CrmDeals,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/custom-fields'),
    name: 'crm_custom_fields',
    component: CrmCustomFields,
    meta: { permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/pipelines'),
    name: 'crm_pipelines',
    component: CrmPipelines,
    meta: { permissions: ['administrator'] },
  },
];
