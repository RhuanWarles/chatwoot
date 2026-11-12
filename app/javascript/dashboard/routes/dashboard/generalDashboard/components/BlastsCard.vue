<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  formatNumber,
  formatPercent,
} from '../../settings/aiAnalytics/analyticsFormat';
import { percentOf } from '../../settings/aiAnalytics/analyticsMetrics';
import AnalyticsCard from '../../settings/aiAnalytics/components/AnalyticsCard.vue';
import { channelKey } from '../dashboardMetrics';

// Broadcasts sent in the period: how much arrived and how many customers wrote back. Only the campaigns that record
// their recipients (WhatsApp) can be followed.
const props = defineProps({
  blasts: { type: Object, default: null },
  period: { type: String, default: '' },
  locale: { type: String, default: 'pt-BR' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});
defineEmits(['retry']);

const { t } = useI18n();
const { accountId } = useAccount();

const count = value => formatNumber(value, props.locale);
const rows = computed(() =>
  (props.blasts?.campaigns || []).map(campaign => ({
    ...campaign,
    channel: t(
      `GENERAL_DASHBOARD.CHANNEL_${channelKey(campaign.channel).toUpperCase()}`
    ),
    deliveredShare: percentOf(campaign.delivered, campaign.sent),
    repliedShare: percentOf(campaign.replied, campaign.sent),
  }))
);
</script>

<template>
  <AnalyticsCard
    :title="t('GENERAL_DASHBOARD.BLASTS')"
    :info="t('GENERAL_DASHBOARD.BLASTS_INFO')"
    :period="period"
    :loading="loading"
    :error="error"
    :empty="!blasts?.sent"
    :empty-text="t('GENERAL_DASHBOARD.BLASTS_EMPTY')"
    data-test="blasts-card"
    @retry="$emit('retry')"
  >
    <template #actions>
      <RouterLink
        :to="{ name: 'campaigns_whatsapp_index', params: { accountId } }"
        class="text-sm text-n-slate-11 underline hover:text-n-slate-12"
        data-test="full-report"
      >
        {{ t('GENERAL_DASHBOARD.ALL_BLASTS') }}
      </RouterLink>
    </template>
    <div class="overflow-x-auto">
      <ul class="m-0 flex min-w-[32rem] list-none flex-col p-0">
        <li
          v-for="campaign in rows"
          :key="campaign.id"
          class="grid grid-cols-[minmax(8rem,1.2fr)_5rem_minmax(0,2fr)_9rem] items-center gap-x-4 border-t border-n-weak py-3 text-sm first:border-t-0"
          data-test="blast-row"
        >
          <div class="min-w-0">
            <p class="m-0 truncate font-medium text-n-slate-12">
              {{ campaign.title }}
            </p>
            <p class="m-0 text-xs text-n-slate-11">{{ campaign.channel }}</p>
          </div>
          <div class="tabular-nums">
            <p class="m-0 font-semibold text-n-slate-12">
              {{ count(campaign.sent) }}
            </p>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('GENERAL_DASHBOARD.SENT') }}
            </p>
          </div>
          <div
            role="img"
            :aria-label="
              t('GENERAL_DASHBOARD.BLAST_ARIA', {
                sent: count(campaign.sent),
                delivered: count(campaign.delivered),
                replied: count(campaign.replied),
              })
            "
            class="flex flex-col gap-1.5"
          >
            <span class="block h-2 overflow-hidden rounded-full bg-n-alpha-3">
              <span
                class="block h-full bg-n-slate-9"
                :style="{ width: `${campaign.deliveredShare || 0}%` }"
              />
            </span>
            <span class="block h-2 overflow-hidden rounded-full bg-n-alpha-3">
              <span
                class="block h-full bg-[var(--an-ai)]"
                :style="{ width: `${campaign.repliedShare || 0}%` }"
              />
            </span>
          </div>
          <p class="m-0 text-xs tabular-nums text-n-slate-11">
            {{ count(campaign.delivered) }}
            {{ t('GENERAL_DASHBOARD.DELIVERED') }}
            <br />
            <strong class="text-sm font-semibold text-n-slate-12">
              {{ count(campaign.replied) }}
              {{ t('GENERAL_DASHBOARD.REPLIED') }} ({{
                formatPercent(campaign.repliedShare, locale, 0)
              }})
            </strong>
          </p>
        </li>
      </ul>
    </div>
  </AnalyticsCard>
</template>
