import { frontendURL } from '../../../helper/URLHelper';
import GeneralDashboard from './GeneralDashboard.vue';

// Who can see the reports can see the dashboard: it is made of the same numbers.
export const routes = [
  {
    path: frontendURL('accounts/:accountId/general-dashboard'),
    name: 'general_dashboard',
    component: GeneralDashboard,
    meta: { permissions: ['administrator', 'report_manage'] },
  },
];
