<script setup>
import { computed, inject } from 'vue';
import TextAgentDetail from './TextAgentDetail.vue';
import VoiceAgentDetail from './VoiceAgentDetail.vue';
import { AGENTS_WORKSPACE } from './workspace';

// Route component of /settings/ai-agents/:agentId. The list lives in Index.vue; this picks the editor
// for the selected type and the agent from that list.
const props = defineProps({
  agentId: {
    type: String,
    required: true,
  },
});

const workspace = inject(AGENTS_WORKSPACE);
const agent = computed(() =>
  workspace.agents.value.find(item => String(item.id) === props.agentId)
);
</script>

<template>
  <VoiceAgentDetail
    v-if="agent && workspace.type.value === 'voice'"
    :agent="agent"
  />
  <TextAgentDetail v-else-if="agent" :agent="agent" />
</template>
