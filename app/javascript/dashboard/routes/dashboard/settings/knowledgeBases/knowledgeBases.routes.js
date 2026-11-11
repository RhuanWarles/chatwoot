import { frontendURL } from '../../../../helper/URLHelper';
import EmptyRoute from '../aiShared/EmptyRoute';
import Index from './Index.vue';
import KnowledgeBaseDetailRoute from './KnowledgeBaseDetailRoute.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      // Master-detail: Index.vue is the list, the child route is the open knowledge base.
      path: frontendURL('accounts/:accountId/settings/knowledge-bases'),
      component: Index,
      meta,
      children: [
        {
          path: '',
          name: 'knowledge_bases_settings',
          component: EmptyRoute,
          meta,
        },
        {
          path: ':knowledgeBaseId(\\d+)',
          name: 'knowledge_base_detail',
          component: KnowledgeBaseDetailRoute,
          props: true,
          meta,
        },
        // Old bookmarks: creating happens in a modal now and editing is the detail itself.
        { path: 'new', redirect: { name: 'knowledge_bases_settings' } },
        {
          path: ':knowledgeBaseId(\\d+)/edit',
          redirect: to => ({
            name: 'knowledge_base_detail',
            params: to.params,
          }),
        },
      ],
    },
  ],
};
