import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-agents'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'ai_agents_settings',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
