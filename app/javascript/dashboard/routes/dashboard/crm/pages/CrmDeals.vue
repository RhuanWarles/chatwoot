<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { debounce } from '@chatwoot/utils';
import { useEventListener } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import ContactAPI from 'dashboard/api/contacts';
import { useAdmin } from 'dashboard/composables/useAdmin';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import CrmDealSearchResults from '../components/CrmDealSearchResults.vue';
import { pipelinesAPI, dealsAPI, segmentsAPI } from 'dashboard/api/crm';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useCrmCardConfig } from '../components/cardConfig';
import { brlFormatter } from '../components/currencyHelpers';
import CrmCardCustomizer from '../components/CrmCardCustomizer.vue';
import CrmCurrencyInput from '../components/CrmCurrencyInput.vue';
import CrmContactPicker from '../components/CrmContactPicker.vue';
import CrmDealCard from '../components/CrmDealCard.vue';
import CrmPipelineEditor from '../components/CrmPipelineEditor.vue';

const { t } = useI18n();
const { isAdmin } = useAdmin();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const segments = ref([]);
const pipelineEditor = ref(null);
const route = useRoute();
const router = useRouter();
const pipelines = ref([]);
const deals = ref([]);
const selectedPipeline = ref('');
const kanbanBoard = ref(null);
const now = ref(Date.now());
let activityClock;
const DRAG_SCROLL_EDGE = 80;
const DRAG_SCROLL_MAX_SPEED = 720;
const DRAG_SCROLL_MAX_FRAME_MS = 32;
let dragScrollFrame;
let dragPointer = null;
let lastDragScrollTime;
const updateDragPointer = event => {
  const pointer = event.touches?.[0] || event;
  dragPointer = { x: pointer.clientX, y: pointer.clientY };
};
const stopDragScroll = () => {
  cancelAnimationFrame(dragScrollFrame);
  dragScrollFrame = null;
  dragPointer = null;
  lastDragScrollTime = null;
};
const dragScrollProximity = (position, start, end) => {
  const edge = Math.min(DRAG_SCROLL_EDGE, (end - start) / 2);
  return (
    Math.max(0, 1 - (end - position) / edge) -
    Math.max(0, 1 - (position - start) / edge)
  );
};
const scrollDuringDrag = timestamp => {
  const board = kanbanBoard.value;
  const elapsed = Math.min(
    timestamp - (lastDragScrollTime ?? timestamp),
    DRAG_SCROLL_MAX_FRAME_MS
  );
  lastDragScrollTime = timestamp;
  if (board && dragPointer) {
    const { left, right, top, bottom } = board.getBoundingClientRect();
    const { x, y } = dragPointer;
    if (x >= left && x <= right && y >= top && y <= bottom) {
      const distance = (DRAG_SCROLL_MAX_SPEED * elapsed) / 1000;
      board.scrollLeft += dragScrollProximity(x, left, right) * distance;
      const column = document
        .elementFromPoint(x, y)
        ?.closest('[data-crm-stage-deals]');
      if (column && board.contains(column)) {
        const rect = column.getBoundingClientRect();
        column.scrollTop +=
          dragScrollProximity(y, rect.top, rect.bottom) * distance;
      }
    }
  }
  dragScrollFrame = requestAnimationFrame(scrollDuringDrag);
};
const startDragScroll = event => {
  stopDragScroll();
  updateDragPointer(event.originalEvent);
  dragScrollFrame = requestAnimationFrame(scrollDuringDrag);
};
useEventListener(document, 'pointermove', updateDragPointer);
useEventListener(document, 'touchmove', updateDragPointer, { passive: true });
useEventListener(
  document,
  ['pointerup', 'pointercancel', 'touchend', 'touchcancel'],
  stopDragScroll
);
useEventListener(window, 'blur', stopDragScroll);
const DRAG_SCROLL_OPTIONS = {
  forceFallback: true,
  fallbackOnBody: true,
  // One animation loop controls both axes, independently of nested scroll roots.
  scroll: false,
  // A release outside any list or outcome zone cancels the move instead of applying the last
  // hovered target, because Won and Lost can fire webhooks and messages.
  revertOnSpill: true,
};
const dragging = ref(false);
const NO_DEALS = [];
const OUTCOME_AUTOMATION_REFRESH_MS = 2000;
const STATUS_KEYS = {
  open: 'CRM.STATUS_OPEN',
  won: 'CRM.STATUS_WON',
  lost: 'CRM.STATUS_LOST',
};
const OUTCOME_ZONES = [
  {
    status: 'won',
    label: 'CRM.DROP_TO_WON',
    icon: 'i-lucide-trophy',
    classes: 'border-n-teal-7 bg-n-teal-3 text-n-teal-11 hover:bg-n-teal-4',
  },
  {
    status: 'lost',
    label: 'CRM.DROP_TO_LOST',
    icon: 'i-lucide-circle-x',
    classes: 'border-n-ruby-7 bg-n-ruby-3 text-n-ruby-11 hover:bg-n-ruby-4',
  },
];
const { fields: cardFields, customFieldIds: cardCustomFieldIds } =
  useCrmCardConfig();
const startDrag = event => {
  dragging.value = true;
  startDragScroll(event);
};
const endDrag = () => {
  dragging.value = false;
  stopDragScroll();
};
const searchDraft = ref('');
const searchQuery = ref('');
const searchError = ref('');
const waitingForSearch = ref(false);
const searchPopover = ref(null);
const searchResults = ref(null);
const searchOpen = ref(false);
const unfilteredDeals = ref([]);
const unfilteredPipeline = ref(null);
const loadedSearch = ref('');
let searchVersion = 0;
const SEARCH_DELAY = 300;
const {
  run: runDeals,
  abort: abortDeals,
  isPending: searching,
} = useAbortableRequest();
const searchBusy = computed(() => searching.value || waitingForSearch.value);
const loadDeals = async () => {
  if (!selectedPipeline.value) return;
  searchVersion += 1;
  const version = searchVersion;
  const pipelineId = Number(selectedPipeline.value);
  const query = searchQuery.value;
  searchError.value = '';
  try {
    const result = await runDeals(signal =>
      dealsAPI.get({
        signal,
        params: { pipeline_id: pipelineId, q: query },
      })
    );
    if (!result || version !== searchVersion) return;
    deals.value = result.data.filter(deal => deal.pipeline_id === pipelineId);
    loadedSearch.value = pipelineId + ':' + query;
    if (!query) {
      unfilteredDeals.value = deals.value;
      unfilteredPipeline.value = pipelineId;
    } else if (unfilteredPipeline.value === pipelineId) {
      const updates = new Map(deals.value.map(deal => [deal.id, deal]));
      unfilteredDeals.value = unfilteredDeals.value.map(
        deal => updates.get(deal.id) || deal
      );
    }
  } catch {
    if (version === searchVersion)
      searchError.value = t('CRM.DEAL_SEARCH_ERROR');
  }
};
const openSearch = () => {
  if (searchDraft.value.trim()) searchPopover.value?.show();
};
const applySearch = (term, version = searchVersion) => {
  if (version !== searchVersion) return;
  if (term !== searchDraft.value.trim()) return;
  waitingForSearch.value = false;
  if (
    term === searchQuery.value &&
    !searchError.value &&
    (searching.value ||
      loadedSearch.value === Number(selectedPipeline.value) + ':' + term)
  )
    return;
  searchQuery.value = term;
  loadDeals();
};
const debouncedSearch = debounce(applySearch, SEARCH_DELAY);
const search = () => {
  openSearch();
  applySearch(searchDraft.value.trim());
};
const clearSearch = () => {
  searchDraft.value = '';
};
watch(
  searchDraft,
  value => {
    searchVersion += 1;
    abortDeals();
    searchError.value = '';
    const term = value.trim();
    if (!term) {
      const hadSearch = Boolean(searchQuery.value || waitingForSearch.value);
      waitingForSearch.value = false;
      searchQuery.value = '';
      searchPopover.value?.hide();
      if (unfilteredPipeline.value === Number(selectedPipeline.value))
        deals.value = unfilteredDeals.value;
      if (hadSearch) loadDeals();
      return;
    }
    waitingForSearch.value = true;
    openSearch();
    debouncedSearch(term, searchVersion);
  },
  { flush: 'sync' }
);
const focusSearchResults = async () => {
  openSearch();
  await nextTick();
  searchResults.value?.focusFirst();
};
const selectedStatuses = ref([]);
const filterDraft = ref(null);
const showFilterPanel = ref(false);
const advancedFilters = ref({
  ownerId: '',
  createdFrom: '',
  createdTo: '',
  updatedFrom: '',
  updatedTo: '',
  stageIds: [],
  segmentIds: [],
  answeredBy: [],
  minValue: '',
  maxValue: '',
  contactId: '',
  company: '',
});
const statusFilters = computed(() => [
  { status: 'open', label: t('CRM.FILTER_OPEN') },
  { status: 'won', label: t('CRM.FILTER_WON') },
  { status: 'lost', label: t('CRM.FILTER_LOST') },
]);
const toggleStatus = status => {
  const statuses = selectedStatuses.value.includes(status)
    ? selectedStatuses.value.filter(item => item !== status)
    : [...selectedStatuses.value, status];
  selectedStatuses.value =
    statuses.length === statusFilters.value.length ? [] : statuses;
};
const showForm = ref(false);
const selectedDeal = ref(null);
const saving = ref(false);
const newValueInput = ref(null);
const editValueInput = ref(null);
const form = ref({
  name: '',
  contact_id: '',
  pipeline_stage_id: '',
  segment_id: '',
  value: '',
  description: '',
});

const pipeline = computed(() =>
  pipelines.value.find(item => item.id === Number(selectedPipeline.value))
);
const stages = computed(() => pipeline.value?.stages || []);
// A deal matches when any of the chosen people, or the AI, replied to the customer.
const answeredByAny = (deal, chosen) =>
  chosen.some(who =>
    who === 'ai'
      ? Boolean(deal.answered_by?.ai)
      : Boolean(deal.answered_by?.user_ids?.includes(who))
  );
const visibleDeals = computed(() =>
  deals.value.filter(deal => {
    const f = advancedFilters.value;
    const created = new Date(deal.created_at);
    const updated = new Date(deal.updated_at);
    const ownerMatches =
      !f.ownerId ||
      (f.ownerId === 'none'
        ? !deal.owner_id
        : deal.owner_id === Number(f.ownerId));
    const company =
      deal.contact?.company?.name ||
      deal.contact?.additional_attributes?.company_name ||
      '';
    const range = (value, from, to) =>
      (!from || value >= new Date(`${from}T00:00:00`)) &&
      (!to || value <= new Date(`${to}T23:59:59.999`));
    return (
      (!selectedStatuses.value.length ||
        selectedStatuses.value.includes(deal.status)) &&
      ownerMatches &&
      (!f.stageIds.length || f.stageIds.includes(deal.pipeline_stage_id)) &&
      (!f.segmentIds.length ||
        f.segmentIds.includes(deal.segment_id ?? 'none')) &&
      (!f.answeredBy.length || answeredByAny(deal, f.answeredBy)) &&
      (!f.contactId || deal.contact_id === Number(f.contactId)) &&
      (!f.company || company.toLowerCase().includes(f.company.toLowerCase())) &&
      range(created, f.createdFrom, f.createdTo) &&
      range(updated, f.updatedFrom, f.updatedTo) &&
      (f.minValue === '' || Number(deal.value || 0) >= Number(f.minValue)) &&
      (f.maxValue === '' || Number(deal.value || 0) <= Number(f.maxValue))
    );
  })
);
const filterCount = computed(() =>
  Object.entries(advancedFilters.value).reduce(
    (count, [, value]) =>
      count +
      (Array.isArray(value) ? Number(value.length > 0) : Number(value !== '')),
    0
  )
);
const ownerOptions = computed(() => [
  { value: '', label: t('CRM.FILTER_ALL') },
  ...new Map(
    deals.value
      .filter(deal => deal.owner)
      .map(deal => [
        deal.owner.id,
        { value: deal.owner.id, label: deal.owner.name },
      ])
  ).values(),
  { value: 'none', label: t('CRM.FILTER_UNASSIGNED') },
]);
const segmentOptions = computed(() => [
  ...segments.value.map(segment => ({
    value: segment.id,
    label: segment.name,
  })),
  { value: 'none', label: t('CRM.NO_SEGMENT') },
]);
const responderOptions = computed(() => [
  { value: 'ai', label: t('CRM.FILTER_AI') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const cloneAdvancedFilters = filters => ({
  ...filters,
  stageIds: [...filters.stageIds],
  segmentIds: [...filters.segmentIds],
  answeredBy: [...filters.answeredBy],
});
const clearAdvancedFilters = () => {
  const target = filterDraft.value || advancedFilters.value;
  Object.assign(target, {
    ownerId: '',
    createdFrom: '',
    createdTo: '',
    updatedFrom: '',
    updatedTo: '',
    stageIds: [],
    segmentIds: [],
    answeredBy: [],
    minValue: '',
    maxValue: '',
    contactId: '',
    company: '',
  });
};
const selectedFilterContact = computed(() => {
  const filters = filterDraft.value || advancedFilters.value;
  return (
    deals.value.find(deal => deal.contact_id === Number(filters.contactId))
      ?.contact || null
  );
});
const openAdvancedFilters = () => {
  filterDraft.value = cloneAdvancedFilters(advancedFilters.value);
  showFilterPanel.value = true;
};
const applyAdvancedFilters = () => {
  advancedFilters.value = cloneAdvancedFilters(filterDraft.value);
  filterDraft.value = null;
  showFilterPanel.value = false;
};
const closeAdvancedFilters = () => {
  filterDraft.value = null;
  showFilterPanel.value = false;
};
const boardStages = computed(() =>
  stages.value.map(stage => {
    const stageDeals = visibleDeals.value.filter(
      deal => deal.pipeline_stage_id === stage.id
    );
    const totalCents = stageDeals.reduce(
      (sum, deal) => sum + Math.round(Number(deal.value || 0) * 100),
      0
    );
    return { ...stage, deals: stageDeals, total: totalCents / 100 };
  })
);
const pipelineOptions = computed(() =>
  pipelines.value.map(item => ({ value: item.id, label: item.name }))
);

const load = async () => {
  const response = await pipelinesAPI.get();
  pipelines.value = response.data;
  const requestedPipeline = pipelines.value.find(
    item => String(item.id) === route.query.pipeline_id
  );
  selectedPipeline.value =
    (
      requestedPipeline ||
      pipelines.value.find(item => item.active) ||
      pipelines.value[0]
    )?.id || '';
  const stageIds = new Set(stages.value.map(stage => stage.id));
  advancedFilters.value.stageIds = advancedFilters.value.stageIds.filter(id =>
    stageIds.has(id)
  );
  if (filterDraft.value) {
    filterDraft.value.stageIds = filterDraft.value.stageIds.filter(id =>
      stageIds.has(id)
    );
  }
  if (selectedPipeline.value) {
    if (route.query.pipeline_id !== String(selectedPipeline.value)) {
      await router.replace({
        query: { ...route.query, pipeline_id: String(selectedPipeline.value) },
      });
    }
    waitingForSearch.value = false;
    searchQuery.value = searchDraft.value.trim();
    await loadDeals();
  }
};

const selectPipeline = async () => {
  await router.replace({
    query: { ...route.query, pipeline_id: String(selectedPipeline.value) },
  });
  await load();
};

const pipelineSaved = async pipelineId => {
  selectedPipeline.value = pipelineId;
  await selectPipeline();
};

watch(
  () => route.query.pipeline_id,
  pipelineId => {
    if (pipelineId !== String(selectedPipeline.value)) load();
  }
);

const openDealDetails = deal => {
  router.push({
    name: 'crm_deal_details',
    params: { accountId: route.params.accountId, dealId: deal.id },
  });
};
// Clicking a card goes to the latest conversation of the customer; without one, the deal page opens instead.
let openingConversation = false;
const openDealConversation = async deal => {
  if (openingConversation) return;
  openingConversation = true;
  try {
    const { data } = await ContactAPI.getConversations(deal.contact_id);
    const latest = data?.payload?.[0];
    if (latest) {
      router.push({
        name: 'inbox_conversation',
        params: {
          accountId: route.params.accountId,
          conversation_id: latest.id,
        },
      });
      return;
    }
    useAlert(t('CRM.NO_CONVERSATION'));
  } catch {
    useAlert(t('CRM.NO_CONVERSATION'));
  } finally {
    openingConversation = false;
  }
  openDealDetails(deal);
};

const openForm = () => {
  form.value = {
    name: '',
    contact_id: '',
    pipeline_stage_id: stages.value[0]?.id || '',
    segment_id: '',
    value: '',
    description: '',
  };
  showForm.value = true;
};

const createDeal = async () => {
  if (saving.value || newValueInput.value?.isInvalid) return;
  saving.value = true;
  try {
    const { segment_id: segmentId, ...fields } = form.value;
    await dealsAPI.create({
      deal: {
        ...fields,
        ...(segmentId ? { segment_id: segmentId } : {}),
        value: form.value.value === '' ? null : form.value.value,
        pipeline_id: selectedPipeline.value,
      },
    });
    showForm.value = false;
    await load();
  } finally {
    saving.value = false;
  }
};

const saveDeal = async () => {
  if (editValueInput.value?.isInvalid) return;
  await dealsAPI.update(selectedDeal.value.id, {
    deal: {
      name: selectedDeal.value.name,
      status: selectedDeal.value.status,
      description: selectedDeal.value.description,
      contact_id: selectedDeal.value.contact_id,
      pipeline_stage_id: selectedDeal.value.pipeline_stage_id,
      value: selectedDeal.value.value === '' ? null : selectedDeal.value.value,
    },
  });
  selectedDeal.value = null;
  await load();
};

const updateDeal = async (deal, changes) => {
  const previous = Object.fromEntries(
    Object.keys(changes).map(key => [key, deal[key]])
  );
  Object.assign(deal, changes);
  try {
    await dealsAPI.update(deal.id, { deal: changes });
    return true;
  } catch {
    Object.assign(deal, previous);
    useAlert(t('CRM.DETAIL_SAVE_ERROR'));
    return false;
  }
};
const moveDeal = (deal, stage) =>
  updateDeal(deal, { pipeline_stage_id: stage.id });
const hasOutcomeAutomations = status =>
  Boolean(pipeline.value?.[status + '_automations']?.length);
let automationRefreshTimer;
let unmounted = false;
const setDealStatus = async (deal, status) => {
  if (deal.status === status || !(await updateDeal(deal, { status }))) return;
  const automations = hasOutcomeAutomations(status);
  useAlert(
    t(
      automations
        ? 'CRM.DEAL_STATUS_UPDATED_AUTOMATIONS'
        : 'CRM.DEAL_STATUS_UPDATED',
      { status: t(STATUS_KEYS[status]).toLowerCase() }
    )
  );
  if (!automations || unmounted) return;
  window.clearTimeout(automationRefreshTimer);
  automationRefreshTimer = window.setTimeout(() => {
    // A reload would bump the search version and drop a search typed meanwhile.
    if (!dragging.value && !waitingForSearch.value) loadDeals();
  }, OUTCOME_AUTOMATION_REFRESH_MS);
};

const loadFilterOptions = async () => {
  try {
    segments.value = (await segmentsAPI.get()).data;
  } catch {
    segments.value = [];
  }
  if (!agents.value.length) store.dispatch('agents/get');
};
onMounted(() => {
  load();
  loadFilterOptions();
  activityClock = window.setInterval(() => {
    now.value = Date.now();
  }, 60 * 1000);
});
onUnmounted(() => {
  unmounted = true;
  stopDragScroll();
  if (activityClock) window.clearInterval(activityClock);
  window.clearTimeout(automationRefreshTimer);
  searchVersion += 1;
});
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-h-0 min-w-0 p-3 md:p-4 overflow-hidden bg-n-background"
  >
    <header class="flex flex-wrap items-center justify-between gap-3 mb-3">
      <div class="flex flex-wrap items-center gap-3 min-w-0">
        <h1 class="mb-0 text-xl font-semibold text-n-slate-12">
          {{ t('CRM.DEALS_TITLE') }}
        </h1>
        <div class="flex items-center gap-1 min-w-0">
          <ComboBox
            v-model="selectedPipeline"
            :options="pipelineOptions"
            :placeholder="t('CRM.SELECT_PIPELINE')"
            class="w-56 max-w-full"
            @update:model-value="selectPipeline"
          >
            <template v-if="isAdmin" #footer="{ close }">
              <Button
                variant="ghost"
                color="slate"
                icon="i-lucide-plus"
                :label="t('CRM.NEW_PIPELINE')"
                class="w-full justify-start"
                @click="
                  close();
                  pipelineEditor.open();
                "
              />
            </template>
          </ComboBox>
          <Button
            v-if="isAdmin && pipeline"
            variant="ghost"
            color="slate"
            icon="i-lucide-settings-2"
            :label="t('CRM.EDIT_PIPELINE')"
            @click="pipelineEditor.open(pipeline)"
          />
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2 min-w-0 max-w-full">
        <div class="w-full sm:w-auto min-w-0 [&>span]:w-full">
          <Popover
            ref="searchPopover"
            align="end"
            disable-mobile-view
            @show="searchOpen = true"
            @hide="searchOpen = false"
          >
            <form
              class="flex items-center gap-1 w-full min-w-0 sm:w-auto"
              @submit.prevent="search"
              @click.stop="openSearch"
            >
              <Input
                v-model="searchDraft"
                type="search"
                :placeholder="t('CRM.DEAL_SEARCH_PLACEHOLDER')"
                :aria-label="t('CRM.DEAL_SEARCH_PLACEHOLDER')"
                :aria-expanded="searchOpen"
                aria-haspopup="true"
                class="flex-1 min-w-0 sm:w-64"
                @focus="openSearch"
                @keydown.down.prevent="focusSearchResults"
              />
              <Button
                type="submit"
                variant="ghost"
                icon="i-lucide-search"
                :aria-label="t('CRM.DEAL_SEARCH_SUBMIT')"
                :disabled="searchBusy"
              />
              <Button
                v-if="searchDraft || searchQuery"
                type="button"
                variant="ghost"
                icon="i-lucide-x"
                :aria-label="t('CRM.DEAL_SEARCH_CLEAR')"
                @click.stop="clearSearch"
              />
            </form>
            <template #content="{ hide }">
              <CrmDealSearchResults
                ref="searchResults"
                :deals="visibleDeals"
                :pipeline="pipeline"
                :query="searchDraft.trim()"
                :loading="searchBusy"
                :error="searchError"
                @close="hide"
              />
            </template>
          </Popover>
        </div>
        <Button
          variant="faded"
          color="slate"
          icon="i-lucide-list-filter"
          :label="
            t('CRM.ADVANCED_FILTERS') + (filterCount ? ` (${filterCount})` : '')
          "
          @click="openAdvancedFilters"
        />
        <Popover align="end">
          <Button
            variant="faded"
            color="slate"
            icon="i-lucide-sliders-horizontal"
            :label="t('CRM.CUSTOMIZE_CARDS')"
          />
          <template #content>
            <CrmCardCustomizer />
          </template>
        </Popover>
        <Button
          :label="t('CRM.NEW_DEAL')"
          :disabled="!pipeline?.active"
          icon="i-lucide-plus"
          @click="openForm"
        />
      </div>
    </header>
    <p v-if="searchError" role="alert" class="text-sm text-n-ruby-11">
      {{ searchError }}
    </p>
    <p v-if="searchBusy" class="text-sm text-n-slate-11">
      {{ t('CRM.DEAL_SEARCH_LOADING') }}
    </p>
    <div
      v-if="searchQuery && !searchBusy && !visibleDeals.length && !searchError"
      class="flex flex-wrap items-center gap-2 mb-3 text-sm text-n-slate-11"
    >
      <span>{{ t('CRM.DEAL_SEARCH_EMPTY') }}</span>
      <Button
        :label="t('CRM.DEAL_SEARCH_CLEAR')"
        variant="ghost"
        size="sm"
        @click="clearSearch"
      />
    </div>
    <div
      role="group"
      :aria-label="t('CRM.STATUS')"
      class="flex flex-wrap items-center gap-2 mb-3"
    >
      <span class="text-sm font-medium text-n-slate-12">{{
        t('CRM.STATUS')
      }}</span>
      <Button
        type="button"
        :label="t('CRM.FILTER_ALL')"
        :variant="selectedStatuses.length ? 'faded' : 'solid'"
        :color="selectedStatuses.length ? 'slate' : 'blue'"
        :aria-pressed="!selectedStatuses.length"
        @click="selectedStatuses = []"
      />
      <Button
        v-for="filter in statusFilters"
        :key="filter.status"
        type="button"
        :label="filter.label"
        :variant="selectedStatuses.includes(filter.status) ? 'solid' : 'faded'"
        :color="selectedStatuses.includes(filter.status) ? 'blue' : 'slate'"
        :aria-pressed="selectedStatuses.includes(filter.status)"
        @click="toggleStatus(filter.status)"
      />
    </div>
    <div
      v-if="showFilterPanel"
      class="fixed inset-0 z-50 flex justify-end bg-n-alpha-black1"
      role="presentation"
      @click.self="closeAdvancedFilters"
    >
      <aside
        class="flex flex-col w-full max-w-lg my-3 me-3 overflow-hidden rounded-xl shadow-lg outline outline-1 outline-n-container bg-n-solid-1"
        role="dialog"
        aria-modal="true"
        :aria-label="t('CRM.ADVANCED_FILTERS')"
      >
        <header
          class="flex items-center justify-between flex-shrink-0 gap-4 px-6 py-5 border-b border-n-weak"
        >
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('CRM.ADVANCED_FILTERS') }}
          </h3>
          <button
            type="button"
            class="p-2 rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            :aria-label="t('GENERAL.CLOSE')"
            @click="closeAdvancedFilters"
          >
            {{ t('GENERAL.CLOSE') }}
          </button>
        </header>
        <div class="flex-1 min-h-0 px-6 py-5 overflow-y-auto">
          <div v-if="filterDraft" class="flex flex-col gap-5">
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">{{
                t('CRM.OWNER')
              }}</label
              ><ComboBox
                v-model="filterDraft.ownerId"
                :options="ownerOptions"
                :placeholder="t('CRM.FILTER_ALL')"
              />
            </div>
            <div class="flex flex-col gap-2">
              <p class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('CRM.FILTER_STAGE') }}
              </p>
              <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-2">
                <label
                  v-for="stage in stages"
                  :key="stage.id"
                  class="flex items-center gap-2 text-sm text-n-slate-12"
                  ><input
                    v-model="filterDraft.stageIds"
                    type="checkbox"
                    :value="stage.id"
                  />{{ stage.name }}</label
                >
              </div>
            </div>
            <div v-if="segmentOptions.length > 1" class="flex flex-col gap-2">
              <p class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('CRM.FILTER_SEGMENT') }}
              </p>
              <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-2">
                <label
                  v-for="option in segmentOptions"
                  :key="option.value"
                  class="flex items-center gap-2 text-sm text-n-slate-12"
                  ><input
                    v-model="filterDraft.segmentIds"
                    type="checkbox"
                    :value="option.value"
                  />{{ option.label }}</label
                >
              </div>
            </div>
            <div class="flex flex-col gap-2">
              <p class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('CRM.FILTER_ANSWERED_BY') }}
              </p>
              <p class="mt-0 mb-0 text-xs text-n-slate-11">
                {{ t('CRM.FILTER_ANSWERED_BY_HINT') }}
              </p>
              <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-2">
                <label
                  v-for="option in responderOptions"
                  :key="option.value"
                  class="flex items-center gap-2 text-sm text-n-slate-12"
                  ><input
                    v-model="filterDraft.answeredBy"
                    type="checkbox"
                    :value="option.value"
                  />{{ option.label }}</label
                >
              </div>
            </div>
            <fieldset class="flex flex-col gap-2">
              <legend class="text-sm font-medium text-n-slate-12">
                {{ t('CRM.FILTER_CREATED_FROM').replace(' de', '') }}
              </legend>
              <div class="grid grid-cols-2 gap-2">
                <Input
                  v-model="filterDraft.createdFrom"
                  type="date"
                  :label="t('CRM.FILTER_CREATED_FROM')"
                /><Input
                  v-model="filterDraft.createdTo"
                  type="date"
                  :label="t('CRM.FILTER_CREATED_TO')"
                />
              </div>
            </fieldset>
            <fieldset class="flex flex-col gap-2">
              <legend class="text-sm font-medium text-n-slate-12">
                {{ t('CRM.FILTER_UPDATED_FROM').replace(' de', '') }}
              </legend>
              <div class="grid grid-cols-2 gap-2">
                <Input
                  v-model="filterDraft.updatedFrom"
                  type="date"
                  :label="t('CRM.FILTER_UPDATED_FROM')"
                /><Input
                  v-model="filterDraft.updatedTo"
                  type="date"
                  :label="t('CRM.FILTER_UPDATED_TO')"
                />
              </div>
            </fieldset>
            <fieldset class="flex flex-col gap-2">
              <legend class="text-sm font-medium text-n-slate-12">
                {{ t('CRM.VALUE') }}
              </legend>
              <div class="grid grid-cols-2 gap-2">
                <CrmCurrencyInput
                  v-model="filterDraft.minValue"
                  :label="t('CRM.FILTER_MIN_VALUE')"
                /><CrmCurrencyInput
                  v-model="filterDraft.maxValue"
                  :label="t('CRM.FILTER_MAX_VALUE')"
                />
              </div>
            </fieldset>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">{{
                t('CRM.FILTER_COMPANY')
              }}</label
              ><Input
                v-model="filterDraft.company"
                :label="t('CRM.FILTER_COMPANY')"
              />
            </div>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">{{
                t('CRM.CONTACT')
              }}</label
              ><CrmContactPicker
                v-model="filterDraft.contactId"
                :contact="selectedFilterContact"
              />
            </div>
          </div>
        </div>
        <footer class="flex-shrink-0 px-6 py-4 border-t border-n-weak">
          <div class="flex justify-between gap-2">
            <Button
              type="button"
              variant="ghost"
              :label="t('CRM.CLEAR_FILTERS')"
              @click="clearAdvancedFilters"
            /><Button
              type="button"
              :label="t('CRM.APPLY_FILTERS')"
              @click="applyAdvancedFilters"
            />
          </div>
        </footer>
      </aside>
    </div>
    <section
      v-if="!pipelines.length"
      class="flex flex-col items-center justify-center flex-1 gap-3"
    >
      <p class="text-n-slate-11">{{ t('CRM.NO_PIPELINE') }}</p>
      <Button
        v-if="isAdmin"
        :label="t('CRM.CREATE_PIPELINE')"
        @click="pipelineEditor.open()"
      />
    </section>
    <section
      ref="kanbanBoard"
      class="flex flex-1 w-full min-w-0 gap-2 min-h-0 overflow-x-auto overflow-y-hidden pb-2 select-none"
    >
      <div
        v-for="stage in boardStages"
        :key="stage.id"
        data-crm-stage-column
        class="flex flex-col flex-1 basis-0 min-w-56 min-h-0 h-full overflow-hidden rounded-xl bg-n-alpha-2 p-2.5"
      >
        <div class="sticky top-0 z-10 flex-shrink-0 mb-2 min-w-0">
          <h2
            :title="stage.name"
            class="mb-1 truncate font-medium text-n-slate-12"
          >
            {{ stage.name }}
          </h2>
          <div class="flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
            <span class="text-sm text-n-slate-11" data-crm-stage-total>
              {{ brlFormatter.format(stage.total) }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ t('CRM.DEAL_COUNT', stage.deals.length) }}
            </span>
          </div>
        </div>
        <Draggable
          :model-value="stage.deals"
          item-key="id"
          group="crm-deals"
          data-crm-stage-deals
          v-bind="DRAG_SCROLL_OPTIONS"
          class="flex flex-col flex-1 gap-2 min-h-0 overflow-y-auto overflow-x-hidden overscroll-y-contain"
          @start="startDrag"
          @end="endDrag"
          @change="event => event.added && moveDeal(event.added.element, stage)"
        >
          <template #item="{ element }">
            <CrmDealCard
              :deal="element"
              :fields="cardFields"
              :custom-field-ids="cardCustomFieldIds"
              :now="now"
              @open="openDealConversation(element)"
              @open-deal="openDealDetails(element)"
              @edit="selectedDeal = { ...element }"
              @set-status="status => setDealStatus(element, status)"
            />
          </template>
        </Draggable>
      </div>
    </section>
    <div
      v-show="dragging"
      aria-hidden="true"
      data-crm-outcome-bar
      class="flex flex-shrink-0 gap-2 pt-2"
    >
      <div
        v-for="outcome in OUTCOME_ZONES"
        :key="outcome.status"
        class="relative flex flex-1 items-center justify-center gap-2 px-3 min-h-14 text-sm font-medium text-center rounded-xl border-2 border-dashed transition-colors"
        :class="outcome.classes"
      >
        <span class="flex-shrink-0 size-4" :class="outcome.icon" />
        <span class="min-w-0">{{ t(outcome.label) }}</span>
        <Draggable
          :model-value="NO_DEALS"
          item-key="id"
          group="crm-deals"
          :sort="false"
          :empty-insert-threshold="0"
          ghost-class="opacity-0"
          :data-crm-outcome-zone="outcome.status"
          class="absolute inset-0 overflow-hidden"
          @change="
            event =>
              event.added && setDealStatus(event.added.element, outcome.status)
          "
        >
          <template #item="{ element }">
            <span :data-id="element.id" />
          </template>
        </Draggable>
      </div>
    </div>
    <div
      v-if="selectedDeal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-black1"
    >
      <form
        class="flex flex-col w-full max-w-lg gap-4 p-6 rounded-xl bg-n-background"
        @submit.prevent="saveDeal"
      >
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('CRM.DEAL_DETAILS') }}
        </h2>
        <Input v-model="selectedDeal.name" :label="t('CRM.NAME')" />
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.STAGE')
          }}</span>
          <ComboBox
            v-model="selectedDeal.pipeline_stage_id"
            :options="
              stages.map(stage => ({ value: stage.id, label: stage.name }))
            "
            :placeholder="t('CRM.STAGE')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.CONTACT')
          }}</span>
          <CrmContactPicker
            v-model="selectedDeal.contact_id"
            :contact="selectedDeal.contact"
          />
        </div>
        <CrmCurrencyInput ref="editValueInput" v-model="selectedDeal.value" />
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.STATUS')
          }}</span>
          <ComboBox
            v-model="selectedDeal.status"
            :options="[
              { value: 'open', label: t('CRM.STATUS_OPEN') },
              { value: 'won', label: t('CRM.STATUS_WON') },
              { value: 'lost', label: t('CRM.STATUS_LOST') },
            ]"
            :placeholder="t('CRM.STATUS')"
          />
        </div>
        <Input
          v-model="selectedDeal.description"
          :label="t('CRM.DESCRIPTION')"
        />
        <div class="flex justify-end gap-2">
          <Button
            type="button"
            variant="faded"
            :label="t('CRM.CANCEL')"
            @click="selectedDeal = null"
          /><Button
            type="submit"
            :label="t('CRM.SAVE_CHANGES')"
            :disabled="editValueInput?.isInvalid"
          />
        </div>
      </form>
    </div>
    <div
      v-if="showForm"
      class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-black1"
    >
      <form
        class="flex flex-col w-full max-w-lg gap-4 p-6 rounded-xl bg-n-background"
        @submit.prevent="createDeal"
      >
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('CRM.NEW_DEAL') }}
        </h2>
        <Input v-model="form.name" :label="t('CRM.NAME')" required />
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.STAGE')
          }}</span>
          <ComboBox
            v-model="form.pipeline_stage_id"
            :options="
              stages.map(stage => ({ value: stage.id, label: stage.name }))
            "
            :placeholder="t('CRM.STAGE')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.CONTACT')
          }}</span>
          <CrmContactPicker v-model="form.contact_id" />
        </div>
        <div
          v-if="segments.some(segment => segment.active)"
          class="flex flex-col gap-1"
        >
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CRM.SEGMENT')
          }}</span>
          <ComboBox
            v-model="form.segment_id"
            :options="[
              { value: '', label: t('CRM.NO_SEGMENT') },
              ...segments
                .filter(segment => segment.active)
                .map(segment => ({ value: segment.id, label: segment.name })),
            ]"
            :placeholder="t('CRM.SEGMENT')"
          />
        </div>
        <CrmCurrencyInput ref="newValueInput" v-model="form.value" />
        <Input v-model="form.description" :label="t('CRM.DESCRIPTION')" />
        <div class="flex justify-end gap-2">
          <Button
            type="button"
            variant="faded"
            :label="t('CRM.CANCEL')"
            @click="showForm = false"
          /><Button
            type="submit"
            :label="t('CRM.CREATE_DEAL')"
            :disabled="newValueInput?.isInvalid"
            :is-loading="saving"
          />
        </div>
      </form>
    </div>
    <CrmPipelineEditor
      ref="pipelineEditor"
      @saved="pipelineSaved"
      @closed="pipelineSaved(selectedPipeline)"
    />
  </main>
</template>
