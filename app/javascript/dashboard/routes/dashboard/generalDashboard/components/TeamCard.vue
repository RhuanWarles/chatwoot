<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { formatNumber } from '../../settings/aiAnalytics/analyticsFormat';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import { formatSeconds } from '../dashboardMetrics';

// The people who answered customers in the period. No SLA of resolution: it depends on someone resolving the conversation.
const props = defineProps({
  agents: { type: Array, default: () => [] },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();
const { accountId } = useAccount();

const rows = computed(() =>
  props.agents.map(agent => ({
    ...agent,
    name: agent.name || t('GENERAL_DASHBOARD.NO_NAME'),
    waitingText: formatNumber(agent.waiting, props.locale),
  }))
);
const count = value => formatNumber(value, props.locale);
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.TEAM')"
    :info="t('GENERAL_DASHBOARD.TEAM_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!agents.length"
    :empty-text="t('GENERAL_DASHBOARD.TEAM_EMPTY')"
    data-test="team-card"
    @retry="$emit('retry')"
  >
    <template #actions>
      <RouterLink
        :to="{ name: 'agent_reports_index', params: { accountId } }"
        class="text-sm text-n-slate-11 underline hover:text-n-slate-12"
        data-test="full-report"
      >
        {{ t('GENERAL_DASHBOARD.FULL_REPORT') }}
      </RouterLink>
    </template>
    <div class="overflow-x-auto">
      <table class="w-full min-w-[28rem] border-collapse text-sm tabular-nums">
        <thead class="text-xs text-n-slate-11">
          <tr>
            <th scope="col" class="py-2 pe-3 text-start font-medium">
              {{ t('GENERAL_DASHBOARD.PERSON') }}
            </th>
            <th scope="col" class="px-3 py-2 text-end font-medium">
              {{ t('GENERAL_DASHBOARD.CONVERSATIONS') }}
            </th>
            <th scope="col" class="px-3 py-2 text-end font-medium">
              {{ t('GENERAL_DASHBOARD.REPLIES') }}
            </th>
            <th scope="col" class="px-3 py-2 text-end font-medium">
              {{ t('GENERAL_DASHBOARD.FIRST_RESPONSE') }}
            </th>
            <th scope="col" class="py-2 ps-3 text-end font-medium">
              {{ t('GENERAL_DASHBOARD.WAITING_SHORT') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="agent in rows"
            :key="agent.id"
            class="border-t border-n-weak"
            data-test="agent-row"
          >
            <th
              scope="row"
              class="py-2.5 pe-3 text-start font-medium text-n-slate-12"
            >
              {{ agent.name }}
            </th>
            <td class="px-3 py-2.5 text-end">
              {{ count(agent.conversations) }}
            </td>
            <td class="px-3 py-2.5 text-end">{{ count(agent.replies) }}</td>
            <td class="px-3 py-2.5 text-end">
              {{ formatSeconds(agent.first_response, locale) }}
            </td>
            <td
              class="py-2.5 ps-3 text-end"
              :class="agent.waiting ? 'text-n-amber-11' : 'text-n-slate-11'"
            >
              {{ agent.waitingText }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </AnalyticsCard>
</template>
