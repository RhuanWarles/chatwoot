import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import ToolEditorPage from './ToolEditorPage.vue';
import Logs from './Logs.vue';
import Workspace from './Workspace.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-tools'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: 'logs',
          name: 'ai_tool_logs',
          component: Logs,
          meta: { permissions: ['administrator'] },
        },
        {
          path: '',
          name: 'ai_tools_settings',
          component: Workspace,
          meta: { permissions: ['administrator'] },
          children: [
            { path: 'new', name: 'ai_tool_new', component: ToolEditorPage, meta: { permissions: ['administrator'] } },
            { path: ':toolId/edit', name: 'ai_tool_edit', component: ToolEditorPage, meta: { permissions: ['administrator'] } },
          ],
        },
      ],
    },
  ],
};
