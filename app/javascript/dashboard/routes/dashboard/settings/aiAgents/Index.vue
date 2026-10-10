<script setup>
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import TextAgents from './TextAgents.vue';
import VoiceAgents from './VoiceAgents.vue';
import { useAccount } from 'dashboard/composables/useAccount';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { currentAccount, accountId } = useAccount();
const tabs = computed(() =>
  [
    { label: t('AI_HUB.TEXT'), value: 'text' },
    { label: t('AI_HUB.VOICE'), value: 'voice' },
  ].filter(tab => currentAccount.value?.features?.[`${tab.value}_ai`])
);
const activeType = computed(() => {
  const requested = route.query.type === 'voice' ? 'voice' : 'text';
  return (
    tabs.value.find(tab => tab.value === requested)?.value ||
    tabs.value[0]?.value
  );
});
const activeTab = computed(() =>
  tabs.value.findIndex(tab => tab.value === activeType.value)
);
watch(
  [activeType, () => route.query.type],
  ([type, requested]) => {
    if (type && requested !== type) {
      router.replace({ query: { ...route.query, type } });
    }
  },
  { immediate: true }
);
const selectTab = tab =>
  router.replace({ query: { ...route.query, type: tab.value } });
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('AI_AGENTS.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_HUB.SUBTITLE') }}</p>
      </div>
      <RouterLink
        v-if="tabs.length"
        :to="{
          name: 'saas_ai_settings',
          params: { accountId: route.params.accountId },
        }"
        class="text-sm text-n-blue-11 hover:underline"
      >
        {{ t('AI_HUB.USAGE') }}
      </RouterLink>
    </header>
    <TabBar
      v-if="tabs.length"
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="selectTab"
    />
    <TextAgents v-if="activeType === 'text'" :key="`text-${accountId}`" />
    <VoiceAgents
      v-else-if="activeType === 'voice'"
      :key="`voice-${accountId}`"
    />
    <p v-else class="text-sm text-n-slate-11">{{ t('AI_HUB.UNAVAILABLE') }}</p>
  </main>
</template>
