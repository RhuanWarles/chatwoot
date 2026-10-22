<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import CrmDealCustomFields from '../crm/components/CrmDealCustomFields.vue';
import { brlFormatter } from '../crm/components/currencyHelpers';

const props = defineProps({
  contact: { type: Object, required: true },
});

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();
const deals = ref([]);
const pipelines = ref([]);
const dealId = ref(null);
const loading = ref(false);
const saving = ref(false);

const deal = computed(() => deals.value.find(item => item.id === dealId.value));
const stageOptions = computed(() =>
  (pipelines.value.find(item => item.id === deal.value?.pipeline_id)?.stages || []).map(
    stage => ({ value: stage.id, label: stage.name })
  )
);
const dealOptions = computed(() =>
  deals.value.map(item => ({
    value: item.id,
    label: `${item.name} · ${item.pipeline_stage?.name || ''}`,
  }))
);

const load = async () => {
  loading.value = true;
  try {
    const [dealsResponse, pipelinesResponse] = await Promise.all([
      dealsAPI.get({ params: { contact_id: props.contact.id } }),
      pipelinesAPI.get(),
    ]);
    pipelines.value = pipelinesResponse.data;
    deals.value = [...dealsResponse.data].sort(
      (a, b) => (b.status === 'open') - (a.status === 'open')
    );
    dealId.value = deals.value[0]?.id ?? null;
  } catch {
    useAlert(t('CRM.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const changeStage = async stageId => {
  const current = deal.value;
  if (!current || stageId === current.pipeline_stage_id) return;
  saving.value = true;
  try {
    await dealsAPI.update(current.id, { deal: { pipeline_stage_id: stageId } });
    await load();
    dealId.value = current.id;
  } catch {
    useAlert(t('CRM.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
};

const createDeal = async () => {
  const pipeline =
    pipelines.value.find(item => item.active && item.stages.length) || null;
  if (!pipeline) {
    useAlert(t('CRM.NO_PIPELINE'));
    return;
  }
  saving.value = true;
  try {
    const { data } = await dealsAPI.create({
      deal: {
        name: props.contact.name,
        contact_id: props.contact.id,
        pipeline_id: pipeline.id,
        pipeline_stage_id: pipeline.stages[0].id,
      },
    });
    await load();
    dealId.value = data.id;
  } catch {
    useAlert(t('CRM.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
};

const openDeal = () =>
  router.push({
    name: 'crm_deal_details',
    params: { accountId: accountId.value, dealId: deal.value.id },
  });

watch(() => props.contact.id, load, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-3 px-2 py-3 min-w-0">
    <p v-if="loading" class="m-0 text-sm text-n-slate-11">
      {{ t('CRM.CF_LOADING') }}
    </p>
    <template v-else-if="deal">
      <ComboBox
        v-if="deals.length > 1"
        :model-value="dealId"
        :options="dealOptions"
        @update:model-value="dealId = $event"
      />
      <div class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">{{ t('CRM.STAGE') }}</span>
        <ComboBox
          :model-value="deal.pipeline_stage_id"
          :options="stageOptions"
          :disabled="saving"
          @update:model-value="changeStage"
        />
      </div>
      <div class="flex items-center justify-between gap-2 text-sm">
        <span class="text-n-slate-11">{{ t('CRM.VALUE') }}</span>
        <span class="font-medium text-n-slate-12">
          {{
            deal.value == null ? t('CRM.NOT_SET') : brlFormatter.format(Number(deal.value))
          }}
        </span>
      </div>
      <CrmDealCustomFields :deal-id="deal.id" />
      <Button
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-external-link"
        :label="t('CRM.LEAD_OPEN_DEAL')"
        @click="openDeal"
      />
    </template>
    <template v-else>
      <p class="m-0 text-sm text-n-slate-11">{{ t('CRM.LEAD_NO_DEAL') }}</p>
      <Button
        size="sm"
        icon="i-lucide-plus"
        :label="t('CRM.NEW_DEAL')"
        :is-loading="saving"
        @click="createDeal"
      />
    </template>
  </div>
</template>
