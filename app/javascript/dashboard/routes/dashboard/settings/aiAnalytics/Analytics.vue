<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useElementSize } from '@vueuse/core';
import { LineChart } from '@chatwoot/viz';
import { useLocale } from 'shared/composables/useLocale';
import Select from 'dashboard/components-next/select/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';

const { t } = useI18n();
const { resolvedLocale } = useLocale();
const loading = ref(true);
const error = ref('');
const chartContainer = ref(null);
const { height: chartHeight, width: chartWidth } =
  useElementSize(chartContainer);
const data = ref(null);
const filters = ref({ period: '7d', ai_agent_id: '', inbox_id: '' });
const start = ref('');
const end = ref('');
const detailPage = ref(1);
const DETAILS_PER_PAGE = 20;
const key = name => t(`AI_ANALYTICS.${name}`);
const number = value =>
  value == null
    ? '—'
    : Number(value).toLocaleString(resolvedLocale.value, {
        maximumFractionDigits: 2,
      });
const percent = value => `${number(value)}%`;
const date = value =>
  new Intl.DateTimeFormat(resolvedLocale.value, {
    day: '2-digit',
    month: '2-digit',
    timeZone: 'UTC',
  }).format(new Date(`${value}T00:00:00Z`));
const periodOptions = computed(() =>
  ['today', '7d', '30d', 'month', 'custom'].map(value => ({
    value,
    label: key(`PERIOD_${value.toUpperCase()}`),
  }))
);
const agentOptions = computed(() => [
  { value: '', label: key('ALL') },
  ...(data.value?.agents || []).map(item => ({
    value: item.id,
    label: item.name,
  })),
]);
const inboxOptions = computed(() => [
  { value: '', label: key('ALL') },
  ...(data.value?.inboxes || []).map(item => ({
    value: item.id,
    label: item.name,
  })),
]);
const cards = computed(() => {
  const billing = data.value?.billing;
  const consumption =
    billing?.mode === 'platform'
      ? { label: 'CREDITS_USED', value: billing.credits_consumed }
      : { label: 'TOKENS', value: billing?.total_tokens };

  return [
    {
      label: 'CONVERSATIONS',
      value: data.value?.summary.conversations,
      icon: 'i-lucide-messages-square',
    },
    {
      label: 'MESSAGES',
      value: data.value?.summary.messages,
      icon: 'i-lucide-send',
    },
    {
      label: 'HANDOFFS',
      value: data.value?.summary.handoffs,
      icon: 'i-lucide-user-round-check',
    },
    {
      ...consumption,
      icon: 'i-lucide-coins',
    },
  ];
});
const chartData = computed(() => ({
  categories: (data.value?.timeseries || []).map(item => date(item.date)),
  series: [
    {
      id: 'conversations',
      label: key('CONVERSATIONS'),
      color: 'rgb(var(--blue-9))',
    },
    { id: 'turns', label: key('TURNS'), color: 'rgb(var(--iris-9))' },
    { id: 'messages', label: key('MESSAGES'), color: 'rgb(var(--teal-9))' },
  ].map(series => ({
    ...series,
    data: (data.value?.timeseries || []).map(item => item[series.id]),
    pointBorderColor: 'rgb(var(--solid-2))',
  })),
}));
const latestPoint = computed(() => {
  const points = data.value?.timeseries || [];
  const point = points[points.length - 1];
  return point
    ? {
        date: date(point.date),
        conversations: number(point.conversations),
        turns: number(point.turns),
        messages: number(point.messages),
      }
    : null;
});
const detailRows = computed(() => {
  const offset = (detailPage.value - 1) * DETAILS_PER_PAGE;
  return (data.value?.timeseries || []).slice(
    offset,
    offset + DETAILS_PER_PAGE
  );
});
const consumption = computed(() => {
  const billing = data.value?.billing;
  if (!billing) return [];
  return billing.mode === 'platform'
    ? [
        ['CREDITS_USED', number(billing.credits_consumed)],
        [
          'CREDITS_AVERAGE',
          number(billing.average_credits_per_conversation),
          'CREDITS_HELP',
        ],
        ['CREDITS_AVAILABLE', number(billing.credits_available)],
      ]
    : [
        ['INPUT_TOKENS', number(billing.prompt_tokens)],
        ['OUTPUT_TOKENS', number(billing.completion_tokens)],
        ['TOKENS', number(billing.total_tokens)],
        [
          'ESTIMATED_COST',
          billing.estimated_cost_usd == null
            ? '—'
            : number(billing.estimated_cost_usd),
        ],
        [
          'COST_AVERAGE',
          billing.average_cost_per_conversation == null
            ? '—'
            : number(billing.average_cost_per_conversation),
        ],
      ];
});
const knowledge = computed(() =>
  data.value
    ? [
        ['QUERIES', number(data.value.knowledge.queries)],
        ['HITS', number(data.value.knowledge.hits)],
        ['HIT_RATE', percent(data.value.knowledge.hit_rate), 'HIT_HELP'],
        ['KNOWLEDGE_CONVERSATIONS', number(data.value.knowledge.conversations)],
        [
          'UTILIZATION',
          percent(data.value.knowledge.utilization_rate),
          'UTILIZATION_HELP',
        ],
      ]
    : []
);
let requestId = 0;
const load = async () => {
  if (
    filters.value.period === 'custom' &&
    (!start.value || !end.value || start.value > end.value)
  )
    return;
  requestId += 1;
  const currentRequest = requestId;
  detailPage.value = 1;
  loading.value = true;
  error.value = '';
  try {
    const params = { ...filters.value };
    if (params.period === 'custom') {
      params.start_at = new Date(`${start.value}T00:00:00`).toISOString();
      params.end_at = new Date(`${end.value}T23:59:59.999`).toISOString();
    }
    const response = await aiAnalyticsAPI.show(params);
    if (currentRequest === requestId) data.value = response.data;
  } catch {
    if (currentRequest === requestId) error.value = key('LOAD_ERROR');
  } finally {
    if (currentRequest === requestId) loading.value = false;
  }
};
onMounted(load);
</script>

<template>
  <main
    class="mx-auto flex h-full min-h-0 w-full max-w-[120rem] min-w-0 flex-col gap-5 overflow-y-auto overscroll-contain px-4 pb-6 text-n-slate-12 sm:px-6 2xl:px-8"
  >
    <div
      class="flex shrink-0 flex-col gap-4 xl:flex-row xl:items-end xl:justify-between"
    >
      <header>
        <h1 class="text-xl font-semibold tracking-tight">{{ key('TITLE') }}</h1>
        <p class="mt-1 text-sm text-n-slate-11">{{ key('SUBTITLE') }}</p>
      </header>
      <section
        class="grid grid-cols-1 gap-3 sm:grid-cols-3 xl:w-[36rem]"
        :aria-label="key('PERIOD')"
      >
        <label class="min-w-0 text-xs font-medium text-n-slate-11"
          >{{ key('PERIOD')
          }}<Select
            v-model="filters.period"
            :options="periodOptions"
            :aria-label="key('PERIOD')"
            class="mt-1 !w-full [&_select]:w-full"
            @update:model-value="load"
        /></label>
        <label class="min-w-0 text-xs font-medium text-n-slate-11"
          >{{ key('AGENT')
          }}<Select
            v-model="filters.ai_agent_id"
            :options="agentOptions"
            :aria-label="key('AGENT')"
            class="mt-1 !w-full [&_select]:w-full"
            @update:model-value="load"
        /></label>
        <label class="min-w-0 text-xs font-medium text-n-slate-11"
          >{{ key('INBOX')
          }}<Select
            v-model="filters.inbox_id"
            :options="inboxOptions"
            :aria-label="key('INBOX')"
            class="mt-1 !w-full [&_select]:w-full"
            @update:model-value="load"
        /></label>
      </section>
    </div>
    <div
      v-if="filters.period === 'custom'"
      class="grid shrink-0 grid-cols-1 items-end gap-3 sm:flex sm:flex-wrap"
    >
      <label class="text-xs text-n-slate-11"
        >{{ key('START')
        }}<input
          v-model="start"
          type="date"
          :max="end || undefined"
          class="!mb-0 mt-1 !w-auto"
      /></label>
      <label class="text-xs text-n-slate-11"
        >{{ key('END')
        }}<input
          v-model="end"
          type="date"
          :min="start || undefined"
          class="!mb-0 mt-1 !w-auto"
      /></label>
      <button
        class="rounded-lg bg-n-blue-9 px-4 py-2 text-sm text-white disabled:opacity-50"
        :disabled="!start || !end || start > end"
        @click="load"
      >
        {{ key('APPLY') }}
      </button>
    </div>
    <div
      v-if="error"
      role="alert"
      class="flex items-center justify-between rounded-lg bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
    >
      {{ error }}<button @click="load">{{ key('RETRY') }}</button>
    </div>
    <div
      v-if="loading"
      role="status"
      :aria-label="key('LOADING')"
      class="flex min-h-0 flex-1 animate-pulse flex-col gap-4"
    >
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div v-for="n in 4" :key="n" class="h-24 rounded-xl bg-n-alpha-2" />
      </div>
      <div class="min-h-[24rem] rounded-xl bg-n-alpha-2" />
    </div>
    <template v-else-if="data && !error">
      <section class="grid shrink-0 grid-cols-2 gap-3 lg:grid-cols-4">
        <article
          v-for="card in cards"
          :key="card.label"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <div
            class="flex items-center justify-between gap-2 text-xs text-n-slate-11"
          >
            <span v-tooltip="card.help ? key(card.help) : ''">{{
              key(card.label)
            }}</span
            ><Icon :icon="card.icon" class="size-4 shrink-0" />
          </div>
          <p
            class="mt-3 text-2xl font-semibold tabular-nums tracking-tight sm:text-3xl"
          >
            {{ number(card.value) }}
          </p>
        </article>
      </section>
      <div class="grid min-h-0 gap-4 lg:grid-cols-3">
        <section
          class="flex min-w-0 flex-col rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:col-span-3"
        >
          <h2 class="shrink-0 text-sm font-semibold">
            {{ key('TIMESERIES') }}
          </h2>
          <div
            ref="chartContainer"
            class="mt-4 flex h-56 min-h-0 items-center justify-center overflow-visible sm:h-64"
          >
            <LineChart
              v-if="data.summary.messages || data.billing.credits_consumed"
              :data="chartData"
              :height="Math.max(60, Math.floor(chartHeight))"
              :width="Math.max(280, Math.floor(chartWidth))"
              :point-radius="3"
              :show-values="false"
              :format-value="number"
              :aria-label="key('TIMESERIES')"
              class="w-full min-w-0 [&_.cw-viz-line__x-tick]:hidden [&_.cw-viz-line__x-tick:nth-child(4n+1)]:block [&_.cw-viz-line__x-tick:last-child]:block [--cw-viz-line-label-color:rgb(var(--slate-11))] [--cw-viz-line-axis-color:rgb(var(--slate-4))] [--cw-viz-line-tooltip-background:rgb(var(--solid-2))] [--cw-viz-line-tooltip-color:rgb(var(--slate-12))]"
            />
            <p v-else class="py-12 text-sm text-n-slate-11">
              {{ key('EMPTY') }}
            </p>
          </div>
          <div
            v-if="latestPoint"
            class="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-n-weak pt-3 text-xs text-n-slate-11"
          >
            <span class="font-medium text-n-slate-12"
              >{{ key('DATE') }}: {{ latestPoint.date }}</span
            ><span
              >{{ key('CONVERSATIONS') }}:
              <strong class="font-medium text-n-slate-12">{{
                latestPoint.conversations
              }}</strong></span
            ><span
              >{{ key('TURNS') }}:
              <strong class="font-medium text-n-slate-12">{{
                latestPoint.turns
              }}</strong></span
            ><span
              >{{ key('MESSAGES') }}:
              <strong class="font-medium text-n-slate-12">{{
                latestPoint.messages
              }}</strong></span
            >
          </div>
          <div
            class="mt-3 flex flex-wrap justify-center gap-4 text-xs text-n-slate-11"
          >
            <span class="flex items-center gap-1"
              ><span class="size-2 rounded-full bg-n-blue-9" />{{
                key('CONVERSATIONS')
              }}</span
            ><span class="flex items-center gap-1"
              ><span class="size-2 rounded-full bg-n-iris-9" />{{
                key('TURNS')
              }}</span
            ><span class="flex items-center gap-1"
              ><span class="size-2 rounded-full bg-n-teal-9" />{{
                key('MESSAGES')
              }}</span
            >
          </div>
        </section>
        <section
          class="flex min-w-0 flex-col rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <h2 class="text-sm font-semibold">{{ key('TOOLS') }}</h2>
          <p class="mt-2 text-xs text-n-slate-11">
            {{ key('EXECUTIONS') }}: {{ number(data.tools.executions) }} ·
            {{ key('SUCCESS') }}: {{ number(data.tools.success) }} ·
            {{ key('FAILURES') }}: {{ number(data.tools.failures) }} ·
            {{ percent(data.tools.success_rate) }}
          </p>
          <div class="mt-4 overflow-x-auto">
            <table
              v-if="data.tools.top.length"
              class="w-full text-xs tabular-nums"
            >
              <thead class="sticky top-0 bg-n-solid-2 text-n-slate-11">
                <tr>
                  <th
                    v-for="label in [
                      'TOOL',
                      'EXECUTIONS',
                      'SUCCESS',
                      'FAILURES',
                      'SUCCESS_RATE',
                    ]"
                    :key="label"
                    class="px-2 py-2 text-start font-medium"
                  >
                    {{ key(label) }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="tool in data.tools.top"
                  :key="tool.id"
                  class="border-b border-n-weak"
                >
                  <td class="max-w-32 truncate px-2 py-2">{{ tool.name }}</td>
                  <td>{{ number(tool.executions) }}</td>
                  <td class="text-n-teal-11">{{ number(tool.success) }}</td>
                  <td class="text-n-ruby-11">{{ number(tool.failures) }}</td>
                  <td>{{ percent(tool.success_rate) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-else class="py-6 text-xs text-n-slate-11">
              {{ key('EMPTY_TOOLS') }}
            </p>
          </div>
        </section>
        <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <h2 class="text-sm font-semibold">{{ key('KNOWLEDGE') }}</h2>
          <dl
            v-if="data.knowledge.queries"
            class="mt-3 grid grid-cols-2 gap-x-4 gap-y-3"
          >
            <div v-for="item in knowledge" :key="item[0]">
              <dt
                v-tooltip="item[2] ? key(item[2]) : ''"
                class="text-xs text-n-slate-11"
              >
                {{ key(item[0]) }}
              </dt>
              <dd class="mt-1 text-base font-medium tabular-nums">
                {{ item[1] }}
              </dd>
            </div>
          </dl>
          <p v-else class="py-6 text-xs text-n-slate-11">
            {{ key('EMPTY_KNOWLEDGE') }}
          </p>
        </section>
        <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <h2 class="text-sm font-semibold">{{ key('CONSUMPTION') }}</h2>
          <dl class="mt-3 grid grid-cols-3 gap-3">
            <div v-for="item in consumption" :key="item[0]">
              <dt
                v-tooltip="item[2] ? key(item[2]) : ''"
                class="text-xs text-n-slate-11"
              >
                {{ key(item[0]) }}
              </dt>
              <dd
                v-tooltip="item[1] === '—' ? key('INSUFFICIENT') : ''"
                class="mt-1 text-base font-medium tabular-nums"
              >
                {{ item[1] }}
              </dd>
            </div>
          </dl>
          <div
            class="mt-4 flex flex-wrap items-center gap-4 border-t border-n-weak pt-3 text-xs text-n-slate-11"
          >
            <span>{{ key('OPERATION') }}</span
            ><span>{{ key('TURNS') }}: {{ number(data.summary.turns) }}</span
            ><span
              >{{ key('HANDOFF_RATE') }}:
              {{ percent(data.summary.handoff_rate) }}</span
            ><span v-tooltip="key('INSUFFICIENT')"
              >{{ key('RESPONSE_TIME') }}: —</span
            >
          </div>
        </section>
        <section
          class="min-w-0 rounded-xl border border-n-weak bg-n-solid-1 lg:col-span-3"
        >
          <h2 class="px-4 py-4 text-sm font-semibold">
            {{ key('DETAILS') }}
          </h2>
          <div class="overflow-x-auto">
            <table
              v-if="data.timeseries.length"
              class="w-full text-xs tabular-nums"
            >
              <thead class="sticky top-0 z-10 bg-n-solid-2 text-n-slate-11">
                <tr>
                  <th
                    v-for="label in [
                      'DATE',
                      'CONVERSATIONS',
                      'TURNS',
                      'MESSAGES',
                      data.billing.mode === 'platform'
                        ? 'CREDITS_USED'
                        : 'TOKENS',
                    ]"
                    :key="label"
                    class="px-3 py-2 text-start font-medium"
                  >
                    {{ key(label) }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="item in detailRows"
                  :key="item.date"
                  class="border-b border-n-weak"
                >
                  <td class="whitespace-nowrap px-3 py-2">
                    {{ date(item.date) }}
                  </td>
                  <td class="px-3">{{ number(item.conversations) }}</td>
                  <td class="px-3">{{ number(item.turns) }}</td>
                  <td class="px-3">{{ number(item.messages) }}</td>
                  <td class="px-3">
                    {{
                      number(
                        data.billing.mode === 'platform'
                          ? item.credits
                          : item.tokens
                      )
                    }}
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-else class="p-4 text-xs text-n-slate-11">{{ key('EMPTY') }}</p>
          </div>
          <PaginationFooter
            v-if="data.timeseries.length > DETAILS_PER_PAGE"
            :current-page="detailPage"
            :total-items="data.timeseries.length"
            :items-per-page="DETAILS_PER_PAGE"
            class="rounded-b-xl"
            @update:current-page="detailPage = $event"
          />
        </section>
      </div>
    </template>
  </main>
</template>
