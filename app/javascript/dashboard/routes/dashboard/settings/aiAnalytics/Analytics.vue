<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import aiAgentsAPI from 'dashboard/api/aiAgents';

const { t } = useI18n();
const loading = ref(true);
const error = ref('');
const data = ref(null);
const agents = ref([]);
const inboxes = ref([]);
const filters = ref({ period: '7d', ai_agent_id: '', inbox_id: '' });

const periodOptions = computed(() => [
  { value: 'today', label: t('AI_ANALYTICS.PERIOD_TODAY') },
  { value: '7d', label: t('AI_ANALYTICS.PERIOD_7D') },
  { value: '30d', label: t('AI_ANALYTICS.PERIOD_30D') },
]);
const formatNumber = value => Number(value || 0).toLocaleString();
const formatPercent = value => `${Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })}%`;
const formatCost = value => (value == null ? '—' : `$${Number(value).toFixed(4)}`);
const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const [analytics, agentResponse] = await Promise.all([
      aiAnalyticsAPI.show(filters.value),
      agents.value.length ? Promise.resolve({ data: { agents: agents.value } }) : aiAgentsAPI.get(),
    ]);
    data.value = analytics.data;
    agents.value = agentResponse.data.agents || [];
    inboxes.value = analytics.data.inboxes || [];
  } catch {
    error.value = t('AI_ANALYTICS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
watch(filters, load, { deep: true });
onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6">
    <header>
      <h1 class="text-xl font-semibold text-n-slate-12">{{ t('AI_ANALYTICS.TITLE') }}</h1>
      <p class="text-sm text-n-slate-11">{{ t('AI_ANALYTICS.SUBTITLE') }}</p>
    </header>
    <section class="flex flex-wrap gap-3 p-4 rounded-xl bg-n-solid-2">
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">{{ t('AI_ANALYTICS.PERIOD') }}<select v-model="filters.period" class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"><option v-for="item in periodOptions" :key="item.value" :value="item.value">{{ item.label }}</option></select></label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">{{ t('AI_ANALYTICS.AGENT') }}<select v-model="filters.ai_agent_id" class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"><option value="">{{ t('AI_ANALYTICS.ALL') }}</option><option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option></select></label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">{{ t('AI_ANALYTICS.INBOX') }}<select v-model="filters.inbox_id" class="h-10 px-3 rounded-lg bg-n-solid-1 border border-n-weak"><option value="">{{ t('AI_ANALYTICS.ALL') }}</option><option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">{{ inbox.name }}</option></select></label>
    </section>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <p v-else-if="loading" role="status" class="text-sm text-n-slate-11">{{ t('AI_ANALYTICS.LOADING') }}</p>
    <template v-else-if="data">
      <section class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <article v-for="card in [
          [t('AI_ANALYTICS.CONVERSATIONS'), data.summary.conversations],
          [t('AI_ANALYTICS.TURNS'), data.summary.turns],
          [t('AI_ANALYTICS.MESSAGES'), data.summary.messages],
          [t('AI_ANALYTICS.HANDOFFS'), data.summary.handoffs]
        ]" :key="card[0]" class="p-4 rounded-xl bg-n-solid-2"><p class="text-sm text-n-slate-11">{{ card[0] }}</p><p class="mt-2 text-2xl font-semibold text-n-slate-12">{{ formatNumber(card[1]) }}</p></article>
      </section>
      <section class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <article class="p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_ANALYTICS.OPERATION') }}</h2><dl class="grid grid-cols-2 gap-4 mt-4 text-sm"><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.HANDOFF_RATE') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatPercent(data.summary.handoff_rate) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.RESPONSE_TIME') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ data.summary.average_response_ms == null ? '—' : `${Math.round(data.summary.average_response_ms)} ms` }}</dd></div></dl></article>
        <article class="p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_ANALYTICS.CONSUMPTION') }}</h2><dl class="grid grid-cols-2 gap-4 mt-4 text-sm"><template v-if="data.billing.mode === 'platform'"><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.CREDITS_USED') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.billing.credits_consumed) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.CREDITS_AVAILABLE') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.billing.credits_available) }}</dd></div></template><template v-else><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.INPUT_TOKENS') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.billing.prompt_tokens) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.OUTPUT_TOKENS') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.billing.completion_tokens) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.TOKENS') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.billing.total_tokens) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.ESTIMATED_COST') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatCost(data.billing.estimated_cost_usd) }}</dd></div></template></dl></article>
      </section>
      <section class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <article class="p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_ANALYTICS.TOOLS') }}</h2><p class="mt-2 text-sm text-n-slate-11">{{ formatNumber(data.tools.executions) }} · {{ formatPercent(data.tools.success_rate) }} {{ t('AI_ANALYTICS.SUCCESS_RATE') }}</p><div v-if="data.tools.top.length" class="mt-4 overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-left text-n-slate-11"><th class="p-2">{{ t('AI_ANALYTICS.TOOL') }}</th><th class="p-2">{{ t('AI_ANALYTICS.EXECUTIONS') }}</th><th class="p-2">{{ t('AI_ANALYTICS.SUCCESS') }}</th><th class="p-2">{{ t('AI_ANALYTICS.FAILURES') }}</th></tr></thead><tbody><tr v-for="item in data.tools.top" :key="item.id"><td class="p-2 text-n-slate-12">{{ item.name }}</td><td class="p-2">{{ item.executions }}</td><td class="p-2 text-n-emerald-11">{{ item.success }}</td><td class="p-2 text-n-ruby-11">{{ item.failures }}</td></tr></tbody></table></div><p v-else class="mt-4 text-sm text-n-slate-11">{{ t('AI_ANALYTICS.EMPTY_TOOLS') }}</p></article>
        <article class="p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_ANALYTICS.KNOWLEDGE') }}</h2><dl class="grid grid-cols-3 gap-4 mt-4 text-sm"><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.QUERIES') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.knowledge.queries) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.HITS') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatNumber(data.knowledge.hits) }}</dd></div><div><dt class="text-n-slate-11">{{ t('AI_ANALYTICS.HIT_RATE') }}</dt><dd class="mt-1 text-lg text-n-slate-12">{{ formatPercent(data.knowledge.hit_rate) }}</dd></div></dl></article>
      </section>
      <section class="p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_ANALYTICS.TIMESERIES') }}</h2><p v-if="!data.timeseries.length" class="mt-4 text-sm text-n-slate-11">{{ t('AI_ANALYTICS.EMPTY') }}</p><div v-else class="mt-4 overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-left text-n-slate-11"><th class="p-2">{{ t('AI_ANALYTICS.DATE') }}</th><th class="p-2">{{ t('AI_ANALYTICS.MESSAGES') }}</th><th class="p-2">{{ t('AI_ANALYTICS.CREDITS_USED') }}</th></tr></thead><tbody><tr v-for="item in data.timeseries" :key="item.date"><td class="p-2 text-n-slate-12">{{ item.date }}</td><td class="p-2">{{ item.messages }}</td><td class="p-2">{{ item.credits }}</td></tr></tbody></table></div></section>
    </template>
  </main>
</template>
