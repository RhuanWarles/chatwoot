<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const props = defineProps({
  // 'rules' (the classic automation rules) or 'workflows' (the visual builder).
  active: { type: String, required: true },
});

const SECTIONS = [
  { key: 'rules', route: 'automation_list' },
  { key: 'workflows', route: 'automation_workflows' },
];

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const tabs = computed(() =>
  SECTIONS.map(section => ({
    key: section.key,
    label: t(`AUTOMATION.WORKFLOWS.SECTIONS.${section.key.toUpperCase()}`),
  }))
);
const activeIndex = computed(() =>
  SECTIONS.findIndex(section => section.key === props.active)
);

const onTabChanged = tab => {
  if (tab.key === props.active) return;
  const { route: name } = SECTIONS.find(section => section.key === tab.key);
  router.push({ name, params: route.params });
};
</script>

<template>
  <TabBar
    :tabs="tabs"
    :initial-active-tab="activeIndex"
    @tab-changed="onTabChanged"
  />
</template>
