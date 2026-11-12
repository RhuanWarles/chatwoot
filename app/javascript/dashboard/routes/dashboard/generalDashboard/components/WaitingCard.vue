<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatNumber } from '../../settings/aiAnalytics/analyticsFormat';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import { formatWaiting, isLongWait } from '../dashboardMetrics';

// Customers who wrote and have no answer yet (from a person or from the AI). It is about right now, not about the period.
const props = defineProps({
  waiting: { type: Object, default: null },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();

const list = computed(() => props.waiting?.list || []);
const total = computed(() => Number(props.waiting?.total || 0));
const hidden = computed(() => Math.max(0, total.value - list.value.length));
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.WAITING')"
    :info="t('GENERAL_DASHBOARD.WAITING_INFO')"
    :period="t('GENERAL_DASHBOARD.RIGHT_NOW')"
    :loading="loading"
    :error="error"
    :empty="!total"
    :empty-text="t('GENERAL_DASHBOARD.WAITING_NONE')"
    data-test="waiting-card"
    @retry="$emit('retry')"
  >
    <ul class="m-0 flex list-none flex-col p-0">
      <li
        v-for="item in list"
        :key="item.id"
        class="flex items-center justify-between gap-3 border-t border-n-weak py-2.5 first:border-t-0"
        data-test="waiting-item"
      >
        <div class="min-w-0">
          <p class="m-0 truncate font-medium text-n-slate-12">
            {{ item.contact || t('GENERAL_DASHBOARD.NO_NAME') }}
          </p>
          <p class="m-0 truncate text-xs text-n-slate-11">
            {{ item.inbox }} ·
            {{ item.assignee || t('GENERAL_DASHBOARD.UNASSIGNED') }}
          </p>
        </div>
        <span
          class="shrink-0 rounded-full px-2.5 py-0.5 text-sm font-semibold tabular-nums"
          :class="
            isLongWait(item.minutes)
              ? 'bg-n-amber-3 text-n-amber-11'
              : 'bg-n-alpha-2 text-n-slate-11'
          "
          :data-long="isLongWait(item.minutes)"
        >
          {{ formatWaiting(item.minutes) }}
        </span>
      </li>
    </ul>
    <p
      v-if="hidden"
      class="m-0 text-xs text-n-slate-11"
      data-test="waiting-hidden"
    >
      {{
        t('GENERAL_DASHBOARD.WAITING_MORE', {
          count: formatNumber(hidden, locale),
        })
      }}
    </p>
  </AnalyticsCard>
</template>
