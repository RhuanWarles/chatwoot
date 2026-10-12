<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  retrieval: { type: Object, required: true },
  interactive: { type: Boolean, default: true },
});
defineEmits(['select']);
const { locale } = useI18n();
const time = computed(() =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(props.retrieval.created_at))
);
const baseNames = computed(() =>
  props.retrieval.knowledge_bases.map(base => base.name).join(', ')
);
</script>

<template>
  <component
    :is="interactive ? 'button' : 'div'"
    class="w-full min-w-0 m-0 p-2 text-start rounded-lg"
    :class="{
      'hover:bg-n-alpha-2 cursor-pointer focus-visible:ring-2 focus-visible:ring-n-blue-9':
        interactive,
    }"
    :type="interactive ? 'button' : undefined"
    @click="interactive && $emit('select', retrieval)"
  >
    <span class="block text-sm font-medium text-n-slate-12 break-words">
      {{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.EVENT') }}
    </span>
    <span class="text-xs text-n-slate-11 break-words">
      {{ baseNames }} · {{ retrieval.accepted_count }}
      {{ $t('CONVERSATION.KNOWLEDGE_RETRIEVAL.CHUNKS') }} · {{ time }}
    </span>
  </component>
</template>
