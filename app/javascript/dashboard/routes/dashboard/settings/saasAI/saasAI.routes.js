import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-voice'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'saas_ai_settings',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
