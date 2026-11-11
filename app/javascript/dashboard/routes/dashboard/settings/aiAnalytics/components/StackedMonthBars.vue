<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  EMPTY,
  formatMonth,
  formatNumber,
  formatPercent,
} from '../analyticsFormat';
import { isCurrentMonth, percentOf } from '../analyticsMetrics';

// Replies per month in absolute numbers, AI on the bottom and people on top, so the size of the month is as visible as the
// split. The percentages are in the tooltip. The month in progress is hatched (it is not finished) and a month without
// replies is a dotted line, not a bar of height zero.
// `rows`: [{ month: 'YYYY-MM', ai_replies, human_replies, ai_share, ai_only_share }]
const props = defineProps({
  rows: { type: Array, required: true },
  locale: { type: String, default: 'pt-BR' },
  now: { type: Date, default: () => new Date() },
});

const { t } = useI18n();
const AREA_HEIGHT = 168;

const highest = computed(() =>
  Math.max(1, ...props.rows.map(row => row.ai_replies + row.human_replies))
);
const columns = computed(() =>
  props.rows.map(row => {
    const total = row.ai_replies + row.human_replies;
    return {
      ...row,
      total,
      label: formatMonth(row.month, props.locale),
      height: total ? Math.max(4, (total / highest.value) * AREA_HEIGHT) : 0,
      inProgress: isCurrentMonth(row.month, props.now),
      aiShare: percentOf(row.ai_replies, total),
      humanShare: percentOf(row.human_replies, total),
    };
  })
);
const progress = column =>
  column.inProgress ? ` (${t('CRM.RESPONDER_REPORT.IN_PROGRESS')})` : '';
const describe = column =>
  column.total
    ? `${column.label}${progress(column)}:${t('CRM.RESPONDER_REPORT.LEGEND_AI')} ${formatNumber(column.ai_replies, props.locale)} (${formatPercent(column.aiShare, props.locale)}), ${t('CRM.RESPONDER_REPORT.LEGEND_HUMAN')} ${formatNumber(column.human_replies, props.locale)} (${formatPercent(column.humanShare, props.locale)})`
    : `${column.label}: ${t('CRM.RESPONDER_REPORT.NO_DATA_MONTH')}`;
</script>

<template>
  <div class="overflow-x-auto overflow-y-hidden pb-1" data-test="month-scroll">
    <ul
      class="m-0 flex list-none items-end gap-1.5 p-0 sm:gap-3"
      :aria-label="t('CRM.RESPONDER_REPORT.TITLE')"
    >
      <li
        v-for="(column, index) in columns"
        :key="column.month"
        class="group relative flex min-w-8 flex-1 flex-col items-center gap-1 rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        tabindex="0"
        :aria-label="describe(column)"
        data-test="month-bar"
      >
        <span class="text-xs font-semibold tabular-nums text-n-slate-12">
          {{ column.total ? formatNumber(column.total, locale) : EMPTY }}
        </span>
        <div
          class="flex w-full items-end justify-center"
          :style="{ height: `${AREA_HEIGHT}px` }"
        >
          <div
            v-if="column.total"
            class="flex w-full max-w-12 flex-col justify-end overflow-hidden rounded-t"
            :class="column.inProgress ? 'opacity-90' : ''"
            :style="{ height: `${column.height}px` }"
            data-test="month-stack"
          >
            <div
              class="bg-[var(--an-people)]"
              :class="{ hatched: column.inProgress }"
              :style="{ flexGrow: column.human_replies }"
              data-test="people-segment"
            />
            <div
              class="bg-[var(--an-ai)]"
              :class="{ hatched: column.inProgress }"
              :style="{ flexGrow: column.ai_replies }"
              data-test="ai-segment"
            />
          </div>
          <div
            v-else
            class="w-full max-w-12 border-b-2 border-dotted border-n-slate-8"
            data-test="no-data-month"
          />
        </div>
        <span class="whitespace-nowrap text-xs text-n-slate-11">{{
          column.label
        }}</span>

        <div
          class="pointer-events-none absolute top-7 z-10 hidden w-44 rounded-lg border border-n-weak bg-n-solid-3 p-2.5 text-xs shadow-lg group-hover:block group-focus-visible:block"
          :class="index < columns.length / 2 ? 'start-0' : 'end-0'"
          aria-hidden="true"
          data-test="month-tooltip"
        >
          <p class="m-0 font-semibold text-n-slate-12">
            {{ column.label }}
            <span v-if="column.inProgress" class="font-normal text-n-slate-11">
              · {{ t('CRM.RESPONDER_REPORT.IN_PROGRESS') }}
            </span>
          </p>
          <dl v-if="column.total" class="m-0 mt-1.5 flex flex-col gap-1">
            <div class="flex items-center justify-between gap-2">
              <dt class="flex items-center gap-1.5 text-n-slate-11">
                <span class="size-2 rounded-full bg-[var(--an-ai)]" />{{
                  t('CRM.RESPONDER_REPORT.LEGEND_AI')
                }}
              </dt>
              <dd class="m-0 tabular-nums text-n-slate-12">
                {{ formatNumber(column.ai_replies, locale) }}
                ({{ formatPercent(column.aiShare, locale) }})
              </dd>
            </div>
            <div class="flex items-center justify-between gap-2">
              <dt class="flex items-center gap-1.5 text-n-slate-11">
                <span class="size-2 rounded-full bg-[var(--an-people)]" />{{
                  t('CRM.RESPONDER_REPORT.LEGEND_HUMAN')
                }}
              </dt>
              <dd class="m-0 tabular-nums text-n-slate-12">
                {{ formatNumber(column.human_replies, locale) }}
                ({{ formatPercent(column.humanShare, locale) }})
              </dd>
            </div>
            <div class="flex items-center justify-between gap-2">
              <dt class="text-n-slate-11">
                {{ t('CRM.RESPONDER_REPORT.COL_AI_ONLY') }}
              </dt>
              <dd class="m-0 tabular-nums text-n-slate-12">
                {{ formatPercent(column.ai_only_share, locale) }}
              </dd>
            </div>
          </dl>
          <p v-else class="m-0 mt-1.5 text-n-slate-11">
            {{ t('CRM.RESPONDER_REPORT.NO_DATA_MONTH') }}
          </p>
        </div>
      </li>
    </ul>
  </div>
</template>
