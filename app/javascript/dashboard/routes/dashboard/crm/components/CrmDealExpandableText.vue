<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
const props = defineProps({ value: { type: String, default: '' } });
const { t } = useI18n();
const expanded = ref(false);
const PREVIEW_LENGTH = 180;
watch(
  () => props.value,
  () => {
    expanded.value = false;
  }
);
</script>

<template>
  <div class="min-w-0">
    <p
      class="m-0 whitespace-pre-wrap break-words text-sm text-n-slate-12"
      :class="{ 'line-clamp-3': !expanded }"
    >
      {{ value || t('CRM.NOT_SET') }}
    </p>
    <button
      v-if="value.length > PREVIEW_LENGTH || value.split('\n').length > 3"
      type="button"
      class="mt-1 text-xs text-n-brand hover:underline"
      :aria-expanded="expanded"
      @click="expanded = !expanded"
    >
      {{ t(expanded ? 'CRM.SIDEBAR_LESS' : 'CRM.SIDEBAR_MORE') }}
    </button>
  </div>
</template>
