<script setup>
import { computed, watch, ref, nextTick } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import CustomToolsPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/CustomToolsPageEmptyState.vue';
import CreateCustomToolDialog from 'dashboard/components-next/captain/pageComponents/customTool/CreateCustomToolDialog.vue';
import CustomToolCard from 'dashboard/components-next/captain/pageComponents/customTool/CustomToolCard.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import AssistantToolsBanner from 'dashboard/components-next/captain/pageComponents/customTool/AssistantToolsBanner.vue';

const store = useStore();
const route = useRoute();
const assistantId = computed(() => route.params.assistantId);
const { t } = useI18n();
const { shouldShowPaywall } = usePolicy();

const uiFlags = useMapGetter('captainCustomTools/getUIFlags');
const { run, isPending: isFetchingTools } = useAbortableRequest();
const records = useMapGetter('captainCustomTools/getRecords');
const customTools = computed(() =>
  records.value.filter(tool => tool.assistant_id === Number(assistantId.value))
);
const search = ref('');
const selectedToolId = ref(null);
const filteredTools = computed(() => {
  const query = search.value.trim().toLowerCase();
  return customTools.value.filter(tool =>
    !query || [tool.title, tool.description].some(value => String(value || '').toLowerCase().includes(query))
  );
});
const activeTool = computed(() => customTools.value.find(tool => tool.id === selectedToolId.value) || customTools.value[0]);
const isFetching = computed(
  () => uiFlags.value.fetchingList || isFetchingTools.value
);
const customToolsMeta = useMapGetter('captainCustomTools/getMeta');

const createDialogRef = ref(null);
const deleteDialogRef = ref(null);
const disableDialogRef = ref(null);
const selectedTool = ref(null);
const dialogType = ref('');
const pendingToggleIds = ref(new Set());
const pendingDisable = ref(null);
const isDisableSaving = ref(false);

const disableConfirmationTitle = computed(() =>
  t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.TITLE', {
    title: pendingDisable.value?.title,
  })
);

const disableConfirmationDescription = computed(() => {
  const count = pendingDisable.value?.enabledScenariosCount || 0;
  return count === 1
    ? t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.DESCRIPTION_ONE', {
        count,
      })
    : t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.DESCRIPTION_OTHER', {
        count,
      });
});

const setTogglePending = (id, isPending) => {
  const pendingIds = new Set(pendingToggleIds.value);
  if (isPending) {
    pendingIds.add(id);
  } else {
    pendingIds.delete(id);
  }
  pendingToggleIds.value = pendingIds;
};

const fetchCustomTools = (page = 1) =>
  run(signal =>
    store.dispatch('captainCustomTools/get', {
      assistantId: assistantId.value,
      page,
      signal,
    })
  );

const onPageChange = page => fetchCustomTools(page);

const openCreateDialog = () => {
  dialogType.value = 'create';
  selectedTool.value = null;
  nextTick(() => createDialogRef.value.dialogRef.open());
};

const openToolPanel = (type, tool) => {
  dialogType.value = type;
  selectedTool.value = tool;
  nextTick(() => createDialogRef.value.dialogRef.open());
};

const handleDelete = tool => {
  selectedTool.value = tool;
  nextTick(() => deleteDialogRef.value.dialogRef.open());
};

const handleAction = ({ action, id }) => {
  const tool = customTools.value.find(item => item.id === id);
  if (action === 'edit' || action === 'view') {
    openToolPanel(action, tool);
  } else if (action === 'delete') {
    handleDelete(tool);
  }
};

const updateCustomToolStatus = async ({ id, enabled }) => {
  try {
    await store.dispatch('captainCustomTools/update', {
      id,
      enabled,
      assistantId: assistantId.value,
    });
    const successMessage = enabled
      ? t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ENABLED')
      : t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.DISABLED');
    useAlert(successMessage);
    return true;
  } catch {
    useAlert(t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ERROR'));
    return false;
  }
};

const toggleCustomTool = async ({ id, enabled }) => {
  if (pendingToggleIds.value.has(id)) return;

  setTogglePending(id, true);

  if (!enabled) {
    try {
      const tool = await store.dispatch('captainCustomTools/show', {
        id,
        assistantId: assistantId.value,
      });
      if (tool.enabled_scenarios_count > 0) {
        pendingDisable.value = {
          id,
          enabled,
          title: tool.title,
          enabledScenariosCount: tool.enabled_scenarios_count,
        };
        await nextTick();
        disableDialogRef.value?.open();
        return;
      }
    } catch {
      useAlert(t('CAPTAIN.CUSTOM_TOOLS.TOGGLE.ERROR'));
      setTogglePending(id, false);
      return;
    }
  }

  await updateCustomToolStatus({ id, enabled });
  setTogglePending(id, false);
};

const handleDisableConfirm = async () => {
  if (!pendingDisable.value) return;

  isDisableSaving.value = true;
  const updated = await updateCustomToolStatus(pendingDisable.value);
  isDisableSaving.value = false;

  if (updated) disableDialogRef.value?.close();
};

const handleDisableDialogClose = () => {
  if (pendingDisable.value) {
    setTogglePending(pendingDisable.value.id, false);
  }
  pendingDisable.value = null;
  isDisableSaving.value = false;
};

const handleDialogClose = () => {
  dialogType.value = '';
  selectedTool.value = null;
};

const handleToolCreated = tool => {
  selectedToolId.value = tool?.id || null;
  fetchCustomTools();
};

const onDeleteSuccess = () => {
  selectedTool.value = null;
  if (customTools.value.length === 0 && customToolsMeta.value.page > 1) {
    onPageChange(customToolsMeta.value.page - 1);
  } else {
    // Refresh current page
    fetchCustomTools(customToolsMeta.value.page);
  }
};

// On a full reload account features load after mount, so the paywall briefly shows;
// watching it too fetches the tools once access resolves, not only when the assistant changes
const showPaywall = computed(() =>
  shouldShowPaywall(FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS)
);

watch(
  [assistantId, showPaywall],
  () => {
    if (!showPaywall.value) fetchCustomTools();
  },
  { immediate: true }
);

watch(customTools, tools => {
  if (!tools.some(tool => tool.id === selectedToolId.value)) selectedToolId.value = tools[0]?.id || null;
}, { immediate: true });
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.CUSTOM_TOOLS.HEADER')"
    :button-label="$t('CAPTAIN.CUSTOM_TOOLS.ADD_NEW')"
    :button-policy="['administrator']"
    :feature-flag="FEATURE_FLAGS.CAPTAIN_CUSTOM_TOOLS"
    :total-count="customToolsMeta.totalCount"
    :current-page="customToolsMeta.page"
    :show-pagination-footer="!isFetching && !!customTools.length"
    :is-fetching="isFetching"
    :is-empty="!customTools.length"
    :show-know-more="false"
    @update:current-page="onPageChange"
    @click="openCreateDialog"
  >
    <template #paywall>
      <CaptainPaywall feature-prefix="CAPTAIN.CUSTOM_TOOLS" />
    </template>

    <template #emptyState>
      <CustomToolsPageEmptyState @click="openCreateDialog" />
    </template>

    <template #controls>
      <AssistantToolsBanner />
    </template>

    <template #body>
      <div class="flex min-h-[32rem] overflow-hidden rounded-xl outline outline-1 outline-n-weak bg-n-solid-1">
        <aside class="flex flex-col w-64 shrink-0 border-e border-n-weak bg-n-solid-2">
          <div class="p-3 border-b border-n-weak">
            <input v-model="search" class="w-full h-9 px-3 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12" :placeholder="t('CAPTAIN.CUSTOM_TOOLS.SEARCH')" />
          </div>
          <div class="flex-1 min-h-0 p-2 overflow-y-auto">
            <button v-for="tool in filteredTools" :key="tool.id" type="button" class="flex flex-col w-full gap-1 px-3 py-2 text-start rounded-lg" :class="tool.id === activeTool?.id ? 'bg-n-alpha-2 outline outline-1 outline-n-weak' : 'hover:bg-n-alpha-2'" @click="selectedToolId = tool.id">
              <span class="text-sm font-medium truncate text-n-slate-12">{{ tool.title }}</span>
              <span class="text-xs text-n-slate-10">{{ tool.http_method }} · {{ tool.enabled ? t('CAPTAIN.CUSTOM_TOOLS.ENABLED') : t('CAPTAIN.CUSTOM_TOOLS.DISABLED') }}</span>
            </button>
          </div>
        </aside>
        <div class="flex-1 min-w-0 p-4 overflow-y-auto">
          <CustomToolCard
            v-if="activeTool"
            :id="activeTool.id"
            :title="activeTool.title"
            :description="activeTool.description"
            :endpoint-url="activeTool.endpoint_url"
            :http-method="activeTool.http_method"
            :auth-type="activeTool.auth_type"
            :param-schema="activeTool.param_schema"
            :enabled="activeTool.enabled"
            :source-metadata="activeTool.source_metadata"
            :is-updating="pendingToggleIds.has(activeTool.id)"
            :created-at="activeTool.created_at"
            :updated-at="activeTool.updated_at"
            @action="handleAction"
            @toggle="toggleCustomTool"
          />
          <CustomToolsPageEmptyState v-else @click="openCreateDialog" />
        </div>
      </div>
    </template>
  </PageLayout>

  <CreateCustomToolDialog
    v-if="dialogType"
    ref="createDialogRef"
    :type="dialogType"
    :selected-tool="selectedTool"
    @close="handleDialogClose"
    @created="handleToolCreated"
  />

  <DeleteDialog
    v-if="selectedTool"
    ref="deleteDialogRef"
    :entity="selectedTool"
    :delete-payload="{ id: selectedTool.id, assistantId }"
    type="CustomTools"
    translation-key="CUSTOM_TOOLS"
    @delete-success="onDeleteSuccess"
  />

  <Dialog
    ref="disableDialogRef"
    type="alert"
    :title="disableConfirmationTitle"
    :description="disableConfirmationDescription"
    :confirm-button-label="
      t('CAPTAIN.CUSTOM_TOOLS.DISABLE_CONFIRMATION.CONFIRM')
    "
    :is-loading="isDisableSaving"
    @confirm="handleDisableConfirm"
    @close="handleDisableDialogClose"
  />
</template>
