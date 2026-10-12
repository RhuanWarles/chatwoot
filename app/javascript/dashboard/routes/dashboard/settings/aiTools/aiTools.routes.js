import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';
import ToolEditorPage from './ToolEditorPage.vue';

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
        {
          path: 'new',
          name: 'ai_tool_new',
          component: ToolEditorPage,
          meta: { permissions: ['administrator'] },
        },
        {
          path: ':toolId/edit',
          name: 'ai_tool_edit',
          component: ToolEditorPage,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
