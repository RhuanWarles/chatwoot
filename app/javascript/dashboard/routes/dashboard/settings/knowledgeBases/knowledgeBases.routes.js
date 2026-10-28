import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';
import KnowledgeBaseEditorPage from './KnowledgeBaseEditorPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/knowledge-bases'),
      component: SettingsWrapper,
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'knowledge_bases_settings',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
        {
          path: 'new',
          name: 'knowledge_base_new',
          component: KnowledgeBaseEditorPage,
          meta: { permissions: ['administrator'] },
        },
        {
          path: ':knowledgeBaseId/edit',
          name: 'knowledge_base_edit',
          component: KnowledgeBaseEditorPage,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
