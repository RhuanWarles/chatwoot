<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  formatNumber,
  formatPercent,
} from '../../settings/aiAnalytics/analyticsFormat';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import StatTile from '../../settings/aiAnalytics/components/StatTile.vue';
import { brlFormatter } from '../../crm/components/currencyHelpers';

// The sales side. The outcome of a lead is the deal (won, lost, in which stage), which the team already updates as part of
// the work, so this block needs nobody to resolve conversations.
const props = defineProps({
  crm: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
const emit = defineEmits(['retry', 'pipeline']);

const { t } = useI18n();
const { accountId } = useAccount();

const pipelines = computed(() => props.crm?.pipelines || []);
const funnel = computed(() => props.crm?.funnel || []);
const most = computed(() =>
  Math.max(1, ...funnel.value.map(stage => stage.deals))
);
const money = value => brlFormatter.format(Number(value || 0));
const count = value => formatNumber(value, props.locale);
const lostReasons = computed(() => props.crm?.lost_reasons || []);
const closed = computed(
  () => Number(props.crm?.won?.deals || 0) + Number(props.crm?.lost?.deals || 0)
);
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.CRM')"
    :info="t('GENERAL_DASHBOARD.CRM_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!crm?.pipeline_id"
    :empty-text="t('GENERAL_DASHBOARD.CRM_EMPTY')"
    data-test="crm-card"
    @retry="$emit('retry')"
  >
    <template #actions>
      <select
        v-if="pipelines.length > 1"
        :value="crm.pipeline_id"
        :aria-label="t('GENERAL_DASHBOARD.PIPELINE')"
        class="mb-0 h-11 rounded-lg px-3 text-sm outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
        data-test="pipeline-select"
        @change="emit('pipeline', Number($event.target.value))"
      >
        <option v-for="item in pipelines" :key="item.id" :value="item.id">
          {{ item.name }}
        </option>
      </select>
      <RouterLink
        :to="{ name: 'crm_deals', params: { accountId } }"
        class="text-sm text-n-slate-11 underline hover:text-n-slate-12"
        data-test="full-report"
      >
        {{ t('GENERAL_DASHBOARD.OPEN_CRM') }}
      </RouterLink>
    </template>

    <p class="m-0 text-xs text-n-slate-11">
      {{ t('GENERAL_DASHBOARD.FUNNEL_NOW') }}
    </p>
    <ul class="m-0 flex list-none flex-col gap-2 p-0">
      <li
        v-for="stage in funnel"
        :key="stage.id"
        class="grid grid-cols-[6.5rem_minmax(0,1fr)_2.5rem_6rem] items-center gap-x-3 text-sm"
        data-test="funnel-stage"
      >
        <span class="truncate text-n-slate-11" :title="stage.name">{{
          stage.name
        }}</span>
        <span
          class="h-2.5 overflow-hidden rounded-full bg-n-alpha-3"
          aria-hidden="true"
        >
          <span
            class="block h-full rounded-full bg-n-slate-12 opacity-80"
            :style="{ width: `${(stage.deals / most) * 100}%` }"
          />
        </span>
        <span class="text-end font-semibold tabular-nums text-n-slate-12">{{
          count(stage.deals)
        }}</span>
        <span class="truncate text-end tabular-nums text-n-slate-11">{{
          money(stage.value)
        }}</span>
      </li>
    </ul>

    <dl class="m-0 grid grid-cols-1 gap-3 sm:grid-cols-3">
      <StatTile
        :label="t('GENERAL_DASHBOARD.WON')"
        :value="count(crm?.won?.deals)"
        :sub="money(crm?.won?.value)"
        data-test="tile-won"
      />
      <StatTile
        :label="t('GENERAL_DASHBOARD.LOST')"
        :value="count(crm?.lost?.deals)"
        :sub="money(crm?.lost?.value)"
        data-test="tile-lost"
      />
      <StatTile
        :label="t('GENERAL_DASHBOARD.WIN_RATE')"
        :info="t('GENERAL_DASHBOARD.WIN_RATE_INFO')"
        :value="formatPercent(crm?.win_rate, locale, 0)"
        :sub="
          closed
            ? t('GENERAL_DASHBOARD.WIN_RATE_OF', {
                won: count(crm?.won?.deals),
                closed: count(closed),
              })
            : ''
        "
        :tone="crm?.win_rate == null ? 'muted' : 'neutral'"
        data-test="tile-win-rate"
      />
    </dl>

    <div v-if="lostReasons.length" class="border-t border-n-weak pt-3">
      <h3 class="m-0 text-xs font-medium text-n-slate-11">
        {{ t('GENERAL_DASHBOARD.LOST_REASONS') }}
      </h3>
      <ul class="m-0 mt-2 flex list-none flex-col p-0" data-test="lost-reasons">
        <li
          v-for="reason in lostReasons"
          :key="reason.id || 'none'"
          class="flex justify-between gap-3 border-t border-n-weak py-1.5 text-sm first:border-t-0"
        >
          <span class="min-w-0 truncate text-n-slate-12">{{
            reason.name || t('GENERAL_DASHBOARD.NO_REASON')
          }}</span>
          <span class="tabular-nums text-n-slate-11">{{
            count(reason.deals)
          }}</span>
        </li>
      </ul>
    </div>
  </AnalyticsCard>
</template>
