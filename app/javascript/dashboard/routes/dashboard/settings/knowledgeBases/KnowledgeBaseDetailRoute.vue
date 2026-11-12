<script setup>
import { computed, inject } from 'vue';
import KnowledgeBaseDetail from './KnowledgeBaseDetail.vue';
import { KNOWLEDGE_WORKSPACE } from './workspace';

// Route component of /settings/knowledge-bases/:knowledgeBaseId. The list lives in Index.vue; this
// picks the base from that list.
const props = defineProps({
  knowledgeBaseId: {
    type: String,
    required: true,
  },
});

const workspace = inject(KNOWLEDGE_WORKSPACE);
const base = computed(() =>
  workspace.bases.value.find(item => String(item.id) === props.knowledgeBaseId)
);
</script>

<template>
  <KnowledgeBaseDetail v-if="base" :base="base" />
  <div v-else />
</template>
