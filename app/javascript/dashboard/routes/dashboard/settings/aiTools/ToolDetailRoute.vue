<script setup>
import { computed, inject } from 'vue';
import ToolDetail from './ToolDetail.vue';
import { TOOLS_WORKSPACE } from './workspace';

// Route component of /settings/ai-tools/:toolId. The list lives in Index.vue; this picks the tool
// from that list.
const props = defineProps({
  toolId: {
    type: String,
    required: true,
  },
});

const workspace = inject(TOOLS_WORKSPACE);
const tool = computed(() =>
  workspace.tools.value.find(item => String(item.id) === props.toolId)
);
</script>

<template>
  <ToolDetail v-if="tool" :tool="tool" />
  <div v-else />
</template>
