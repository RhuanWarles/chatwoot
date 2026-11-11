import { frontendURL } from '../../../../helper/URLHelper';
import EmptyRoute from '../aiShared/EmptyRoute';
import Index from './Index.vue';
import ToolDetailRoute from './ToolDetailRoute.vue';
import Logs from './Logs.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      // Master-detail: Index.vue is the list, the child route is the open tool (or the logs).
      path: frontendURL('accounts/:accountId/settings/ai-tools'),
      component: Index,
      meta,
      children: [
        {
          path: '',
          name: 'ai_tools_settings',
          component: EmptyRoute,
          meta,
        },
        {
          path: 'logs',
          name: 'ai_tool_logs',
          component: Logs,
          meta,
        },
        {
          path: ':toolId(\\d+)',
          name: 'ai_tool_detail',
          component: ToolDetailRoute,
          props: true,
          meta,
        },
        // Old bookmarks: creating happens in a modal now and editing is the detail itself.
        { path: 'new', redirect: { name: 'ai_tools_settings' } },
        {
          path: ':toolId(\\d+)/edit',
          redirect: to => ({ name: 'ai_tool_detail', params: to.params }),
        },
      ],
    },
  ],
};
