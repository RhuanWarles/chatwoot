<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  formatNumber,
  formatPercent,
} from '../../settings/aiAnalytics/analyticsFormat';
import {
  isCurrentMonth,
  percentOf,
} from '../../settings/aiAnalytics/analyticsMetrics';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import StackedMonthBars from '../../settings/aiAnalytics/components/StackedMonthBars.vue';
import StatTile from '../../settings/aiAnalytics/components/StatTile.vue';

// How much of the service the AI is taking over, month by month (the same report as in the AI analytics), with the
// numbers of the period at the top. The detail (tokens, tools, knowledge base) stays in the AI analytics screen.
const props = defineProps({
  ai: { type: Object, default: null },
  attendance: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();
const { accountId } = useAccount();

const report = ref(null);
const reportLoading = ref(true);
const reportFailed = ref(false);
const load = async () => {
  reportLoading.value = true;
  reportFailed.value = false;
  try {
    const { data } = await aiAnalyticsAPI.replies({ months: 6 });
    report.value = data;
  } catch {
    reportFailed.value = true;
  } finally {
    reportLoading.value = false;
  }
};
onMounted(load);

const months = computed(() => report.value?.months || []);
const hasMonths = computed(() =>
  months.value.some(row => row.ai_replies + row.human_replies > 0)
);
const hasMonthInProgress = computed(() =>
  months.value.some(row => isCurrentMonth(row.month))
);
const replies = computed(() => props.attendance?.replies);
const handled = computed(() => props.attendance?.handled);
const count = value => formatNumber(value, props.locale);
const handoffs = computed(() => props.ai?.summary?.handoffs);
const aiConversations = computed(() => props.ai?.summary?.conversations);
const tools = computed(() => props.ai?.tools);
const knowledge = computed(() => props.ai?.knowledge);
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.AI')"
    :info="t('GENERAL_DASHBOARD.AI_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!ai"
    :empty-text="t('GENERAL_DASHBOARD.AI_OFF')"
    data-test="ai-card"
    @retry="$emit('retry')"
  >
    <template #actions>
      <RouterLink
        :to="{ name: 'ai_analytics_settings', params: { accountId } }"
        class="text-sm text-n-slate-11 underline hover:text-n-slate-12"
        data-test="full-report"
      >
        {{ t('GENERAL_DASHBOARD.OPEN_AI_ANALYTICS') }}
      </RouterLink>
    </template>

    <dl class="m-0 grid grid-cols-1 gap-3 sm:grid-cols-3">
      <StatTile
        :label="t('GENERAL_DASHBOARD.AI_REPLIES_SHARE')"
        :info="t('GENERAL_DASHBOARD.AI_REPLIES_SHARE_INFO')"
        :value="formatPercent(replies?.ai_share, locale, 0)"
        :tone="replies?.ai_share == null ? 'muted' : 'neutral'"
        data-test="tile-ai-share"
      />
      <StatTile
        :label="t('GENERAL_DASHBOARD.AI_ONLY')"
        :info="t('GENERAL_DASHBOARD.AI_ONLY_INFO')"
        :value="formatPercent(handled?.ai_only_share, locale, 0)"
        :tone="handled?.ai_only_share == null ? 'muted' : 'neutral'"
        data-test="tile-ai-only"
      />
      <StatTile
        :label="t('GENERAL_DASHBOARD.HANDOFFS')"
        :info="t('GENERAL_DASHBOARD.HANDOFFS_INFO')"
        :value="count(handoffs)"
        :sub="
          aiConversations
            ? formatPercent(percentOf(handoffs, aiConversations), locale)
            : ''
        "
        data-test="tile-handoffs"
      />
    </dl>

    <div class="flex flex-col gap-2">
      <h3 class="m-0 text-xs font-medium text-n-slate-11">
        {{ t('GENERAL_DASHBOARD.AI_MONTHS') }}
      </h3>
      <div
        v-if="reportLoading"
        role="status"
        :aria-label="t('AI_ANALYTICS.LOADING')"
        class="h-40 animate-pulse rounded-lg bg-n-alpha-2"
      />
      <p
        v-else-if="reportFailed"
        role="alert"
        class="m-0 text-sm text-n-ruby-11"
      >
        {{ t('AI_ANALYTICS.LOAD_ERROR') }}
        <button type="button" class="min-h-11 px-2 underline" @click="load">
          {{ t('AI_ANALYTICS.RETRY') }}
        </button>
      </p>
      <p v-else-if="!hasMonths" class="m-0 text-sm text-n-slate-11">
        {{ t('AI_ANALYTICS.NO_DATA') }}
      </p>
      <StackedMonthBars v-else :rows="months" :locale="locale" />
      <ul
        v-if="hasMonths"
        class="m-0 flex list-none flex-wrap gap-x-5 gap-y-1.5 p-0 text-xs text-n-slate-11"
      >
        <li class="flex items-center gap-1.5">
          <span
            class="size-2.5 rounded-sm bg-[var(--an-ai)]"
            aria-hidden="true"
          />
          {{ t('CRM.RESPONDER_REPORT.LEGEND_AI') }}
        </li>
        <li class="flex items-center gap-1.5">
          <span
            class="size-2.5 rounded-sm bg-[var(--an-people)]"
            aria-hidden="true"
          />
          {{ t('CRM.RESPONDER_REPORT.LEGEND_HUMAN') }}
        </li>
        <li v-if="hasMonthInProgress" class="flex items-center gap-1.5">
          <span
            class="hatched size-2.5 rounded-sm bg-[var(--an-ai)]"
            aria-hidden="true"
          />
          {{ t('CRM.RESPONDER_REPORT.IN_PROGRESS') }}
        </li>
      </ul>
    </div>

    <div
      class="flex flex-wrap gap-x-6 gap-y-1 border-t border-n-weak pt-3 text-sm text-n-slate-11"
      data-test="ai-summary"
    >
      <span v-if="tools?.executions">
        {{
          t('GENERAL_DASHBOARD.TOOLS_SUMMARY', {
            rate: formatPercent(tools.success_rate, locale, 0),
            count: count(tools.executions),
          })
        }}
      </span>
      <span v-if="knowledge?.queries">
        {{
          t('GENERAL_DASHBOARD.KNOWLEDGE_SUMMARY', {
            rate: formatPercent(knowledge.hit_rate, locale, 0),
            count: count(knowledge.queries),
          })
        }}
      </span>
    </div>
  </AnalyticsCard>
</template>
