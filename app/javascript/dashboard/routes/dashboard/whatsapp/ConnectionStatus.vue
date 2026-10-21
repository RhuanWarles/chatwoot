<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({ status: { type: String, required: true } });
const { t } = useI18n();
const STATUS_CLASSES = {
  connected: 'bg-n-teal-3 text-n-teal-11',
  connecting: 'bg-n-blue-3 text-n-blue-11',
  disconnected: 'bg-n-slate-3 text-n-slate-11',
  error: 'bg-n-ruby-3 text-n-ruby-11',
  unavailable: 'bg-n-amber-3 text-n-amber-11',
};
const badgeClass = computed(() => STATUS_CLASSES[props.status]);
</script>

<template>
  <span
    class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-label-small"
    :class="badgeClass"
    role="status"
  >
    <span class="size-1.5 rounded-full bg-current" aria-hidden="true" />
    {{ t(`WHATSAPP_CONNECTIONS.STATUS.${status.toUpperCase()}`) }}
  </span>
</template>
