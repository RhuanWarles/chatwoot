import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-tools'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'ai_tools_settings',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
