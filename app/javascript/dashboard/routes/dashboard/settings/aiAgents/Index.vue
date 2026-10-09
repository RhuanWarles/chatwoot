<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import TextAgents from './TextAgents.vue';
import VoiceAgents from './VoiceAgents.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const activeTab = computed(() => (route.query.type === 'voice' ? 1 : 0));
const tabs = computed(() => [
  { label: t('AI_HUB.TEXT'), value: 'text' },
  { label: t('AI_HUB.VOICE'), value: 'voice' },
]);
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
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="selectTab"
    />
    <TextAgents v-if="activeTab === 0" />
    <VoiceAgents v-else />
  </main>
</template>
