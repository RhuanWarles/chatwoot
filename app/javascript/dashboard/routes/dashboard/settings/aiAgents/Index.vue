<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
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
const listRef = ref(null);
const newAgentLabel = computed(() =>
  activeType.value === 'voice' ? t('AI_HUB.NEW_VOICE') : t('AI_AGENTS.NEW')
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
const openNewAgent = () => listRef.value?.openNew();
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6 px-1 pb-6">
    <header
      class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between"
    >
      <div>
        <h1 class="text-heading-1 text-n-slate-12">
          {{ t('AI_AGENTS.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('AI_HUB.SUBTITLE') }}</p>
      </div>
      <div
        v-if="tabs.length"
        class="flex flex-wrap items-center gap-3 md:justify-end"
      >
        <RouterLink
          :to="{
            name: 'saas_ai_settings',
            params: { accountId: route.params.accountId },
          }"
          class="text-sm text-n-blue-11 hover:underline focus-visible:underline"
        >
          {{ t('AI_HUB.USAGE') }}
        </RouterLink>
        <Button
          :label="newAgentLabel"
          icon="i-lucide-plus"
          :disabled="!listRef?.canCreate"
          @click="openNewAgent"
        />
      </div>
    </header>
    <TabBar
      v-if="tabs.length"
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="selectTab"
    />
    <TextAgents
      v-if="activeType === 'text'"
      ref="listRef"
      :key="`text-${accountId}`"
    />
    <VoiceAgents
      v-else-if="activeType === 'voice'"
      ref="listRef"
      :key="`voice-${accountId}`"
    />
    <p v-else class="text-sm text-n-slate-11">{{ t('AI_HUB.UNAVAILABLE') }}</p>
  </main>
</template>
