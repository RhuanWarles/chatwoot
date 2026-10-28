import { frontendURL } from '../../../../helper/URLHelper';
import AiWorkspaceSettingsWrapper from '../AiWorkspaceSettingsWrapper.vue';
import Playground from './Playground.vue';
import AgentEditorPage from './AgentEditorPage.vue';
import Workspace from './Workspace.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-agents'),
      component: AiWorkspaceSettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'ai_agents_settings',
          component: Workspace,
          meta: { permissions: ['administrator'], reuseOnQueryChange: true },
          children: [
            { path: 'new', name: 'ai_agent_new', component: AgentEditorPage, meta: { permissions: ['administrator'] } },
            { path: ':agentId/edit', name: 'ai_agent_edit', component: AgentEditorPage, meta: { permissions: ['administrator'] } },
          ],
        },
        {
          path: ':agentId/playground',
          name: 'ai_agent_playground',
          component: Playground,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
