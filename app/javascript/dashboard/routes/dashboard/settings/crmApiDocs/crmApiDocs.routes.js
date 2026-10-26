import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import CrmApiDocs from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/crm-api'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'crm_api_docs_settings',
          component: CrmApiDocs,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
