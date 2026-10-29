import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Automation from './Index.vue';
import WorkflowList from './workflows/WorkflowList.vue';
import WorkflowEditor from './workflows/WorkflowEditor.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.AUTOMATIONS,
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/automation'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'automation_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'automation_list',
          component: Automation,
          meta,
        },
        {
          path: 'workflows',
          name: 'automation_workflows',
          component: WorkflowList,
          meta,
        },
      ],
    },
    {
      // The canvas needs the whole viewport and must not be cached between workflows.
      path: frontendURL('accounts/:accountId/settings/automation/workflow'),
      component: SettingsWrapper,
      props: { fullHeight: true, wide: true, keepAlive: false },
      meta,
      children: [
        {
          path: 'new',
          name: 'automation_workflow_new',
          component: WorkflowEditor,
          meta,
        },
        {
          path: ':workflowId',
          name: 'automation_workflow_edit',
          component: WorkflowEditor,
          meta,
        },
      ],
    },
  ],
};
