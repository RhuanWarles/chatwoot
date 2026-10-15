import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Analytics from './Analytics.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-analytics'),
      component: SettingsWrapper,
      props: { fullHeight: true },
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'ai_analytics_settings',
          component: Analytics,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
