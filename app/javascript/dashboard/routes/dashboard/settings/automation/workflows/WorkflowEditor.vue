<script setup>
import { computed, onMounted, provide, ref, watch } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useEventListener } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NodeInspector from './components/inspector/NodeInspector.vue';
import RunHistoryPanel from './components/RunHistoryPanel.vue';
import RunTestDialog from './components/RunTestDialog.vue';
import WorkflowCanvas from './components/WorkflowCanvas.vue';
import WorkflowPalette from './components/WorkflowPalette.vue';
import WorkflowToolbar from './components/WorkflowToolbar.vue';
import { NODE_ISSUES_KEY } from './workflowContext';
import { provideWorkflowLookups } from './useWorkflowLookups';
import { useWorkflowEditor } from './useWorkflowEditor';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

provideWorkflowLookups();
const editor = useWorkflowEditor(route.params.workflowId);
const { nodes, edges, name, description } = editor;
provide(NODE_ISSUES_KEY, editor.issuesByNode);

const canvasRef = ref(null);
const historyRef = ref(null);
const testRef = ref(null);
const leaveDialogRef = ref(null);
const selectedId = ref(null);

const selectedNode = computed(
  () => nodes.value.find(node => node.id === selectedId.value) || null
);
const selectedIssues = computed(
  () => editor.issuesByNode.value[selectedId.value] || []
);
const issueCount = computed(() =>
  editor.showValidation.value ? editor.validation.value.issues.length : 0
);

const issueHint = computed(() =>
  [...new Set(editor.validation.value.issues.map(issue => issue.code))]
    .map(code => t(`AUTOMATION.WORKFLOWS.VALIDATION.${code}`))
    .join(' ')
);

// Deleting a node from the canvas (Delete key) must not leave the inspector pointing at it.
watch(nodes, list => {
  if (selectedId.value && !list.some(node => node.id === selectedId.value)) {
    selectedId.value = null;
  }
});

const goBack = () =>
  router.push({ name: 'automation_workflows', params: route.params });

const save = async () => {
  const wasNew = !editor.id.value;
  const saved = await editor.save();
  if (saved && wasNew) {
    router.replace({
      name: 'automation_workflow_edit',
      params: { ...route.params, workflowId: saved.id },
    });
  }
};

const removeSelected = () => {
  editor.removeNode(selectedId.value);
  selectedId.value = null;
};

const copyWebhook = async () => {
  await copyTextToClipboard(editor.workflow.value?.webhook_url);
  useAlert(t('AUTOMATION.WORKFLOWS.EDITOR.WEBHOOK_COPIED'));
};

const openTest = () => {
  if (editor.isDirty.value) {
    useAlert(t('AUTOMATION.WORKFLOWS.TEST.SAVE_FIRST'));
    return;
  }
  testRef.value?.open();
};

// Leaving with unsaved changes asks first: the guard waits for the dialog's answer.
let answerLeave = null;
onBeforeRouteLeave(() => {
  if (!editor.isDirty.value) return true;
  leaveDialogRef.value?.open();
  return new Promise(resolve => {
    answerLeave = resolve;
  });
});
const confirmLeave = () => {
  answerLeave?.(true);
  answerLeave = null;
  leaveDialogRef.value?.close();
};
const stayOnPage = () => {
  answerLeave?.(false);
  answerLeave = null;
};
useEventListener(window, 'beforeunload', event => {
  if (!editor.isDirty.value) return;
  event.preventDefault();
  Object.assign(event, { returnValue: '' });
});

onMounted(editor.load);
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 gap-3">
    <WorkflowToolbar
      v-model:name="name"
      v-model:description="description"
      :active="editor.active.value"
      :is-saving="editor.isSaving.value"
      :is-dirty="editor.isDirty.value"
      :is-saved="Boolean(editor.id.value)"
      :has-webhook="editor.hasWebhookTrigger.value"
      :issue-count="issueCount"
      :issue-hint="issueHint"
      @back="goBack"
      @save="save"
      @test="openTest"
      @history="historyRef?.open()"
      @copy-webhook="copyWebhook"
      @toggle-active="editor.setActive"
    />
    <woot-loading-state
      v-if="editor.isLoading.value"
      :message="t('AUTOMATION.WORKFLOWS.EDITOR.LOADING')"
    />
    <div
      v-else
      class="flex flex-1 min-h-0 overflow-hidden rounded-xl outline outline-1 outline-n-weak"
    >
      <WorkflowPalette
        @add="(type, preset) => canvasRef?.addNode(type, preset)"
      />
      <WorkflowCanvas
        ref="canvasRef"
        v-model:nodes="nodes"
        v-model:edges="edges"
        @select="selectedId = $event"
      />
      <NodeInspector
        :node="selectedNode"
        :issues="selectedIssues"
        @update:data="editor.updateNodeData(selectedId, $event)"
        @delete="removeSelected"
      />
    </div>
    <RunHistoryPanel
      ref="historyRef"
      :workflow-id="editor.id.value"
      :nodes="nodes"
    />
    <Dialog
      ref="leaveDialogRef"
      type="alert"
      :title="t('AUTOMATION.WORKFLOWS.EDITOR.LEAVE_TITLE')"
      :description="t('AUTOMATION.WORKFLOWS.EDITOR.LEAVE_CONFIRM')"
      :confirm-button-label="t('AUTOMATION.WORKFLOWS.EDITOR.LEAVE_ACTION')"
      :cancel-button-label="t('AUTOMATION.WORKFLOWS.EDITOR.LEAVE_STAY')"
      @confirm="confirmLeave"
      @close="stayOnPage"
    />
    <RunTestDialog
      ref="testRef"
      :workflow-id="editor.id.value"
      @started="historyRef?.open()"
    />
  </div>
</template>
