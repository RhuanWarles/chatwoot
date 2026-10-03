<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import { brlFormatter } from '../components/currencyHelpers';
import CrmCurrencyInput from '../components/CrmCurrencyInput.vue';
import CrmContactPicker from '../components/CrmContactPicker.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const pipelines = ref([]);
const deals = ref([]);
const selectedPipeline = ref('');
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
  value: '',
  description: '',
});

const pipeline = computed(() =>
  pipelines.value.find(item => item.id === Number(selectedPipeline.value))
);
const stages = computed(() => pipeline.value?.stages || []);
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
const clearAdvancedFilters = () => {
  const target = filterDraft.value || advancedFilters.value;
  Object.assign(target, {
    ownerId: '',
    createdFrom: '',
    createdTo: '',
    updatedFrom: '',
    updatedTo: '',
    stageIds: [],
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
  filterDraft.value = structuredClone(advancedFilters.value);
  showFilterPanel.value = true;
};
const applyAdvancedFilters = () => {
  advancedFilters.value = structuredClone(filterDraft.value);
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
  if (!selectedPipeline.value && pipelines.value.length)
    selectedPipeline.value = (
      pipelines.value.find(item => item.active) || pipelines.value[0]
    ).id;
  if (selectedPipeline.value) {
    const result = await dealsAPI.get();
    deals.value = result.data.filter(
      deal => deal.pipeline_id === Number(selectedPipeline.value)
    );
  }
};

const openForm = () => {
  form.value = {
    name: '',
    contact_id: '',
    pipeline_stage_id: stages.value[0]?.id || '',
    value: '',
    description: '',
  };
  showForm.value = true;
};

const createDeal = async () => {
  if (saving.value || newValueInput.value?.isInvalid) return;
  saving.value = true;
  try {
    await dealsAPI.create({
      deal: {
        ...form.value,
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

const moveDeal = async (deal, stage) => {
  const previous = deal.pipeline_stage_id;
  deal.pipeline_stage_id = stage.id;
  try {
    await dealsAPI.update(deal.id, { deal: { pipeline_stage_id: stage.id } });
  } catch (error) {
    deal.pipeline_stage_id = previous;
    throw error;
  }
};

onMounted(load);
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-h-0 min-w-0 p-4 md:p-6 overflow-hidden bg-n-background"
  >
    <header class="flex flex-wrap items-center justify-between gap-3 mb-4">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('CRM.DEALS_TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('CRM.DEALS_SUBTITLE') }}</p>
      </div>
      <div class="flex flex-wrap items-center gap-3">
        <ComboBox
          v-model="selectedPipeline"
          :options="pipelineOptions"
          :placeholder="t('CRM.SELECT_PIPELINE')"
          class="w-56 max-w-full"
          @update:model-value="load"
        /><Button
          :label="t('CRM.NEW_DEAL')"
          :disabled="!pipeline?.active"
          icon="i-lucide-plus"
          @click="openForm"
        />
      </div>
    </header>
    <div
      role="group"
      :aria-label="t('CRM.STATUS')"
      class="flex flex-wrap items-center gap-2 mb-4"
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
    <div class="flex justify-end mb-4">
      <button
        type="button"
        class="inline-flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium rounded-lg bg-n-slate-9/10 text-n-slate-12 hover:bg-n-slate-9/20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        @click="openAdvancedFilters"
      >
        {{ t('CRM.ADVANCED_FILTERS')
        }}{{ filterCount ? '(' + filterCount + ')' : '' }}
      </button>
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
      <RouterLink
        class="text-n-brand"
        :to="{
          name: 'crm_pipelines',
          params: { accountId: route.params.accountId },
        }"
      >
        {{ t('CRM.CREATE_PIPELINE') }}
      </RouterLink>
    </section>
    <section v-else class="flex flex-1 gap-3 min-h-0 overflow-auto pb-2">
      <div
        v-for="stage in boardStages"
        :key="stage.id"
        class="flex flex-col flex-1 flex-shrink-0 w-72 min-w-[18rem] min-h-full h-fit rounded-xl bg-n-alpha-2 p-3"
      >
        <div class="mb-3">
          <div class="flex items-center justify-between gap-2">
            <h2 class="font-medium text-n-slate-12">{{ stage.name }}</h2>
            <span class="flex-shrink-0 text-xs text-n-slate-10">{{
              t('CRM.DEAL_COUNT', stage.deals.length)
            }}</span>
          </div>
          <p class="mt-1 mb-0 text-sm text-n-slate-11">
            {{ brlFormatter.format(stage.total) }}
          </p>
        </div>
        <Draggable
          :model-value="stage.deals"
          item-key="id"
          group="crm-deals"
          class="flex flex-col flex-1 gap-2 min-h-24"
          @change="event => event.added && moveDeal(event.added.element, stage)"
        >
          <template #item="{ element }">
            <article
              class="p-3 rounded-lg border border-n-weak bg-n-background shadow-sm cursor-grab transition-colors hover:border-n-strong"
              @click="
                router.push({
                  name: 'crm_deal_details',
                  params: {
                    accountId: route.params.accountId,
                    dealId: element.id,
                  },
                })
              "
            >
              <div class="flex items-start justify-between gap-2">
                <p class="min-w-0 mb-0 font-medium text-n-slate-12 break-words">
                  {{ element.name }}
                </p>
                <Button
                  type="button"
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-pencil"
                  :aria-label="t('CRM.QUICK_EDIT')"
                  @click.stop="selectedDeal = { ...element }"
                />
                <span
                  v-if="element.status === 'won'"
                  class="inline-flex flex-shrink-0 items-center rounded-md px-2 py-1 text-label-small bg-n-teal-3 text-n-teal-11"
                >
                  {{ t('CRM.STATUS_WON') }}
                </span>
                <span
                  v-else-if="element.status === 'lost'"
                  class="inline-flex flex-shrink-0 items-center rounded-md px-2 py-1 text-label-small bg-n-ruby-3 text-n-ruby-11"
                >
                  {{ t('CRM.STATUS_LOST') }}
                </span>
              </div>
              <p class="mt-1 mb-0 text-xs text-n-slate-11 break-words">
                {{ element.contact?.name }}
              </p>
              <p
                v-if="element.value != null && element.value !== ''"
                class="mt-2 mb-0 text-sm font-medium text-n-slate-12"
              >
                {{ brlFormatter.format(Number(element.value)) }}
              </p>
              <p v-if="element.owner" class="mt-1 text-xs text-n-slate-10">
                {{ element.owner.name }}
              </p>
            </article>
          </template>
        </Draggable>
      </div>
    </section>
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
  </main>
</template>
