import { frontendURL } from '../../../helper/URLHelper';
import CrmDealDetails from './pages/CrmDealDetails.vue';
import CrmDeals from './pages/CrmDeals.vue';
import CrmPipelines from './pages/CrmPipelines.vue';
import CrmCustomFields from './pages/CrmCustomFields.vue';
import CrmSegments from './pages/CrmSegments.vue';
import CrmLostReasons from './pages/CrmLostReasons.vue';

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
    path: frontendURL('accounts/:accountId/crm/segments'),
    name: 'crm_segments',
    component: CrmSegments,
    meta: { permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/lost-reasons'),
    name: 'crm_lost_reasons',
    component: CrmLostReasons,
    meta: { permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/crm/pipelines'),
    name: 'crm_pipelines',
    component: CrmPipelines,
    meta: { permissions: ['administrator'] },
  },
];
