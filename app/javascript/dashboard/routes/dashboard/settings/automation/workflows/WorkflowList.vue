<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import automationWorkflowsAPI, {
  workflowLostReasonsAPI,
} from 'dashboard/api/automationWorkflows';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { BaseTable } from 'dashboard/components-next/table';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import AutomationSectionSwitch from './components/AutomationSectionSwitch.vue';
import WorkflowRow from './components/WorkflowRow.vue';
import WorkflowTemplateDialog from './components/WorkflowTemplateDialog.vue';
import { serializeGraph } from './graph';
import { templateNameKey } from './templates';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const workflows = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);
const selected = ref(null);
const templateDialogRef = ref(null);
const deleteDialogRef = ref(null);

const errorMessage = (error, fallback) =>
  error?.response?.data?.message || error?.response?.data?.error || fallback;

const tableHeaders = computed(() => [
  t('AUTOMATION.WORKFLOWS.LIST.TABLE_HEADER.NAME'),
  t('AUTOMATION.WORKFLOWS.LIST.TABLE_HEADER.TRIGGERS'),
  t('AUTOMATION.WORKFLOWS.LIST.TABLE_HEADER.LAST_RUN'),
  t('AUTOMATION.WORKFLOWS.LIST.TABLE_HEADER.ACTIVE'),
  t('AUTOMATION.WORKFLOWS.LIST.TABLE_HEADER.ACTIONS'),
]);

const load = async () => {
  isLoading.value = true;
  try {
    const { data } = await automationWorkflowsAPI.get();
    workflows.value = Array.isArray(data) ? data : [];
  } catch (error) {
    useAlert(errorMessage(error, t('AUTOMATION.WORKFLOWS.LIST.LOAD_ERROR')));
  } finally {
    isLoading.value = false;
  }
};

const openEditor = workflow =>
  router.push({
    name: 'automation_workflow_edit',
    params: { ...route.params, workflowId: workflow.id },
  });

const createNew = () =>
  router.push({ name: 'automation_workflow_new', params: route.params });

const createFromTemplate = async template => {
  isCreating.value = true;
  try {
    // The loss reasons are read lazily: only the reason-routing template needs them.
    const lostReasons = template.needsReasons
      ? (await workflowLostReasonsAPI.get()).data
      : [];
    const graph = template.build({ t, lostReasons });
    const { data } = await automationWorkflowsAPI.create({
      automation_workflow: {
        name: t(templateNameKey(template.key)),
        description: '',
        active: false,
        graph: serializeGraph(graph.nodes, graph.edges),
      },
    });
    templateDialogRef.value?.close();
    openEditor(data);
  } catch (error) {
    useAlert(errorMessage(error, t('AUTOMATION.WORKFLOWS.LIST.CREATE_ERROR')));
  } finally {
    isCreating.value = false;
  }
};

const toggleActive = async workflow => {
  try {
    const { data } = await automationWorkflowsAPI.update(workflow.id, {
      automation_workflow: { active: !workflow.active },
    });
    Object.assign(workflow, data);
    useAlert(
      t(
        data.active
          ? 'AUTOMATION.WORKFLOWS.LIST.ACTIVATED'
          : 'AUTOMATION.WORKFLOWS.LIST.DEACTIVATED'
      )
    );
  } catch (error) {
    useAlert(errorMessage(error, t('AUTOMATION.WORKFLOWS.LIST.TOGGLE_ERROR')));
  }
};

const duplicate = async workflow => {
  try {
    await automationWorkflowsAPI.create({
      automation_workflow: {
        name: t('AUTOMATION.WORKFLOWS.LIST.COPY_NAME', { name: workflow.name }),
        description: workflow.description,
        active: false,
        graph: workflow.graph,
      },
    });
    useAlert(t('AUTOMATION.WORKFLOWS.LIST.DUPLICATED'));
    load();
  } catch (error) {
    useAlert(errorMessage(error, t('AUTOMATION.WORKFLOWS.LIST.CREATE_ERROR')));
  }
};

const askDelete = workflow => {
  selected.value = workflow;
  deleteDialogRef.value?.open();
};

const confirmDelete = async () => {
  try {
    await automationWorkflowsAPI.delete(selected.value.id);
    workflows.value = workflows.value.filter(
      item => item.id !== selected.value.id
    );
    useAlert(t('AUTOMATION.WORKFLOWS.LIST.DELETED'));
    deleteDialogRef.value?.close();
  } catch (error) {
    useAlert(errorMessage(error, t('AUTOMATION.WORKFLOWS.LIST.DELETE_ERROR')));
  }
};

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('AUTOMATION.WORKFLOWS.LIST.LOADING')"
    :no-records-found="!workflows.length"
    :no-records-message="t('AUTOMATION.WORKFLOWS.LIST.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('AUTOMATION.WORKFLOWS.HEADER')"
        :description="t('AUTOMATION.WORKFLOWS.DESCRIPTION')"
      >
        <template #actions>
          <div class="flex items-center gap-2">
            <AutomationSectionSwitch active="workflows" />
            <Button
              faded
              slate
              sm
              icon="i-lucide-layout-template"
              :label="t('AUTOMATION.WORKFLOWS.LIST.FROM_TEMPLATE')"
              @click="templateDialogRef?.open()"
            />
            <Button
              sm
              icon="i-lucide-plus"
              :label="t('AUTOMATION.WORKFLOWS.LIST.NEW')"
              @click="createNew"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable :headers="tableHeaders" :items="workflows">
        <template #row="{ items }">
          <WorkflowRow
            v-for="workflow in items"
            :key="workflow.id"
            :workflow="workflow"
            @toggle="toggleActive"
            @edit="openEditor"
            @duplicate="duplicate"
            @delete="askDelete"
          />
        </template>
      </BaseTable>
    </template>
    <WorkflowTemplateDialog
      ref="templateDialogRef"
      :is-creating="isCreating"
      @pick="createFromTemplate"
    />
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('AUTOMATION.WORKFLOWS.LIST.DELETE_TITLE')"
      :description="
        t('AUTOMATION.WORKFLOWS.LIST.DELETE_DESCRIPTION', {
          name: selected?.name,
        })
      "
      :confirm-button-label="t('AUTOMATION.WORKFLOWS.LIST.DELETE')"
      @confirm="confirmDelete"
    />
  </SettingsLayout>
</template>
