import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import EmptyRoute from '../aiShared/EmptyRoute';
import Index from './Index.vue';
import AgentDetail from './AgentDetail.vue';
import Playground from './Playground.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      // The test page keeps the full-height page layout.
      path: frontendURL(
        'accounts/:accountId/settings/ai-agents/:agentId/playground'
      ),
      component: SettingsWrapper,
      meta,
      children: [
        {
          path: '',
          name: 'ai_agent_playground',
          component: Playground,
          meta: { ...meta, fullHeight: true, wide: true },
        },
      ],
    },
    {
      // Master-detail: Index.vue is the list, the child route is the open assistant.
      path: frontendURL('accounts/:accountId/settings/ai-agents'),
      component: Index,
      meta,
      children: [
        {
          path: '',
          name: 'ai_agents_settings',
          component: EmptyRoute,
          meta,
        },
        {
          path: ':agentId(\\d+)',
          name: 'ai_agent_detail',
          component: AgentDetail,
          props: true,
          meta,
        },
        // Old bookmarks: creating happens in a modal now and editing is the detail itself.
        { path: 'new', redirect: { name: 'ai_agents_settings' } },
        {
          path: ':agentId(\\d+)/edit',
          redirect: to => ({ name: 'ai_agent_detail', params: to.params }),
        },
      ],
    },
  ],
};
