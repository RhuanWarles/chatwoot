<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import CrmCurrencyInput from '../components/CrmCurrencyInput.vue';
import CrmContactPicker from '../components/CrmContactPicker.vue';

const { t } = useI18n();
const route = useRoute();
const pipelines = ref([]);
const deals = ref([]);
const selectedPipeline = ref('');
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
const dealsByStage = stageId =>
  deals.value.filter(deal => deal.pipeline_stage_id === stageId);
const pipelineOptions = computed(() =>
  pipelines.value.map(item => ({ value: item.id, label: item.name }))
);

const load = async () => {
  const response = await pipelinesAPI.get();
  pipelines.value = response.data;
  if (!selectedPipeline.value && pipelines.value.length)
    selectedPipeline.value = pipelines.value[0].id;
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
  <main class="flex flex-col h-full min-w-0 p-6 overflow-auto bg-n-background">
    <header class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('CRM.DEALS_TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('CRM.DEALS_SUBTITLE') }}</p>
      </div>
      <div class="flex items-center gap-3">
        <ComboBox
          v-model="selectedPipeline"
          :options="pipelineOptions"
          :placeholder="t('CRM.SELECT_PIPELINE')"
          class="w-56"
          @update:model-value="load"
        /><Button
          :label="t('CRM.NEW_DEAL')"
          icon="i-lucide-plus"
          @click="openForm"
        />
      </div>
    </header>
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
    <section v-else class="flex gap-4 min-h-0 overflow-x-auto">
      <div
        v-for="stage in stages"
        :key="stage.id"
        class="flex flex-col flex-shrink-0 w-72 rounded-xl bg-n-alpha-2 p-3"
      >
        <div class="flex items-center justify-between mb-3">
          <h2 class="font-medium text-n-slate-12">{{ stage.name }}</h2>
          <span class="text-xs text-n-slate-10">{{
            dealsByStage(stage.id).length
          }}</span>
        </div>
        <Draggable
          :model-value="dealsByStage(stage.id)"
          item-key="id"
          group="crm-deals"
          class="flex flex-col flex-1 gap-2 min-h-24"
          @change="event => event.added && moveDeal(event.added.element, stage)"
        >
          <template #item="{ element }">
            <article
              class="p-3 rounded-lg bg-n-background shadow-sm cursor-grab"
              @click="selectedDeal = { ...element }"
            >
              <p class="font-medium text-n-slate-12">{{ element.name }}</p>
              <p class="text-xs text-n-slate-11">{{ element.contact?.name }}</p>
              <p v-if="element.value" class="mt-2 text-sm text-n-slate-12">
                {{ element.value }}
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
        <ComboBox
          v-model="selectedDeal.status"
          :options="[
            { value: 'open', label: t('CRM.STATUS_OPEN') },
            { value: 'won', label: t('CRM.STATUS_WON') },
            { value: 'lost', label: t('CRM.STATUS_LOST') },
          ]"
          :placeholder="t('CRM.STATUS')"
        /><Input
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
