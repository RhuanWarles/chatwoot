<script setup>
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  id: {
    type: [String, Number],
    required: true,
  },
});

const { t } = useI18n();

const copy = async () => {
  try {
    await copyTextToClipboard(props.id);
    useAlert(t('AI_HUB.ID_COPIED'));
  } catch {
    useAlert(t('AI_HUB.ID_COPY_ERROR'));
  }
};
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-1.5 px-2 py-1 font-mono text-xs rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
    :aria-label="t('AI_HUB.COPY_ID')"
    @click="copy"
  >
    <span>{{ t('AI_HUB.ID') }} {{ id }}</span>
    <span class="i-lucide-copy size-3.5" aria-hidden="true" />
  </button>
</template>
