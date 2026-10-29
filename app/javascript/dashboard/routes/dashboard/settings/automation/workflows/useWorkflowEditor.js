import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import automationWorkflowsAPI from 'dashboard/api/automationWorkflows';
import { NODE_TYPES } from './constants';
import {
  createNode,
  graphSignature,
  hydrateGraph,
  outputHandles,
  serializeGraph,
  triggerEventsOf,
  validateGraph,
} from './graph';

const FIRST_TRIGGER_POSITION = { x: 80, y: 120 };

const errorMessage = (error, fallback) =>
  error?.response?.data?.message || error?.response?.data?.error || fallback;

export const useWorkflowEditor = initialId => {
  const { t } = useI18n();

  const id = ref(initialId || null);
  const workflow = ref(null);
  const name = ref('');
  const description = ref('');
  const active = ref(false);
  const nodes = ref([]);
  const edges = ref([]);
  const isLoading = ref(false);
  const isSaving = ref(false);
  const showValidation = ref(false);
  const savedSignature = ref('');

  const signature = computed(() =>
    graphSignature({
      name: name.value,
      description: description.value,
      active: active.value,
      nodes: nodes.value,
      edges: edges.value,
    })
  );
  const isDirty = computed(() => signature.value !== savedSignature.value);
  const validation = computed(() => validateGraph(nodes.value, edges.value));
  const issuesByNode = computed(() =>
    showValidation.value ? validation.value.byNode : {}
  );
  const hasWebhookTrigger = computed(() =>
    triggerEventsOf(nodes.value).includes('webhook')
  );

  const apply = record => {
    workflow.value = record;
    name.value = record.name || '';
    description.value = record.description || '';
    active.value = Boolean(record.active);
    ({ nodes: nodes.value, edges: edges.value } = hydrateGraph(record.graph));
    savedSignature.value = signature.value;
  };

  const startEmpty = () => {
    nodes.value = [
      createNode(NODE_TYPES.TRIGGER, { position: FIRST_TRIGGER_POSITION }),
    ];
    edges.value = [];
    savedSignature.value = signature.value;
  };

  const load = async () => {
    if (!id.value) {
      startEmpty();
      return;
    }
    isLoading.value = true;
    try {
      const { data } = await automationWorkflowsAPI.show(id.value);
      apply(data);
    } catch (error) {
      useAlert(
        errorMessage(error, t('AUTOMATION.WORKFLOWS.EDITOR.LOAD_ERROR'))
      );
    } finally {
      isLoading.value = false;
    }
  };

  // Returns the saved record, or null when the save was refused or failed.
  const save = async () => {
    showValidation.value = true;
    name.value = name.value.trim();
    if (!name.value) {
      useAlert(t('AUTOMATION.WORKFLOWS.EDITOR.NAME_REQUIRED'));
      return null;
    }
    if (active.value && !validation.value.valid) {
      useAlert(t('AUTOMATION.WORKFLOWS.EDITOR.FIX_BEFORE_ACTIVATE'));
      return null;
    }
    isSaving.value = true;
    try {
      const payload = {
        automation_workflow: {
          name: name.value,
          description: description.value,
          active: active.value,
          graph: serializeGraph(nodes.value, edges.value),
        },
      };
      const { data } = id.value
        ? await automationWorkflowsAPI.update(id.value, payload)
        : await automationWorkflowsAPI.create(payload);
      workflow.value = data;
      id.value = data.id;
      savedSignature.value = signature.value;
      useAlert(t('AUTOMATION.WORKFLOWS.EDITOR.SAVED'));
      return data;
    } catch (error) {
      useAlert(
        errorMessage(error, t('AUTOMATION.WORKFLOWS.EDITOR.SAVE_ERROR'))
      );
      return null;
    } finally {
      isSaving.value = false;
    }
  };

  // Turning a workflow on is refused while any block is incomplete.
  const setActive = value => {
    if (value && !validation.value.valid) {
      showValidation.value = true;
      useAlert(t('AUTOMATION.WORKFLOWS.EDITOR.FIX_BEFORE_ACTIVATE'));
      return;
    }
    active.value = value;
  };

  const updateNodeData = (nodeId, data) => {
    nodes.value = nodes.value.map(node =>
      node.id === nodeId ? { ...node, data } : node
    );
    // Removing a switch case or changing a node type leaves lines on handles that no longer exist.
    const node = nodes.value.find(item => item.id === nodeId);
    const handles = outputHandles(node).map(handle => handle.id);
    const kept = edges.value.filter(
      edge => edge.source !== nodeId || handles.includes(edge.sourceHandle)
    );
    if (kept.length !== edges.value.length) edges.value = kept;
  };

  const removeNode = nodeId => {
    nodes.value = nodes.value.filter(node => node.id !== nodeId);
    edges.value = edges.value.filter(
      edge => edge.source !== nodeId && edge.target !== nodeId
    );
  };

  return {
    id,
    workflow,
    name,
    description,
    active,
    nodes,
    edges,
    isLoading,
    isSaving,
    isDirty,
    validation,
    issuesByNode,
    showValidation,
    hasWebhookTrigger,
    load,
    save,
    setActive,
    updateNodeData,
    removeNode,
  };
};
