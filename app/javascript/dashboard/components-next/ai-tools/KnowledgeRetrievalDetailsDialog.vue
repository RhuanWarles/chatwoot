<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import knowledgeRetrievals from 'dashboard/api/knowledgeRetrievals';

const props = defineProps({
  retrievalId: { type: Number, required: true },
  conversationId: { type: [Number, String], required: true },
});
const emit = defineEmits(['close']);
const { t, locale } = useI18n();
const dialog = ref(null);
const detail = ref(null);
const loading = ref(false);
const error = ref(false);
const attempt = ref(0);

watch(
  [() => props.retrievalId, () => props.conversationId, attempt],
  async (_, __, onCleanup) => {
    let active = true;
    onCleanup(() => {
      active = false;
    });
    detail.value = null;
    error.value = false;
    loading.value = true;
    try {
      const { data } = await knowledgeRetrievals.show(
        props.conversationId,
        props.retrievalId
      );
      if (active) detail.value = data.retrieval;
    } catch {
      if (active) error.value = true;
    } finally {
      if (active) loading.value = false;
    }
  },
  { immediate: true }
);

const fields = computed(() => {
  if (!detail.value) return [];
  return [
    ['QUERY', detail.value.query],
    ['BASES', detail.value.knowledge_bases.map(base => base.name).join(', ')],
    ['ACCEPTED', detail.value.accepted_count],
    ['TOP_K', detail.value.top_k],
    ['THRESHOLD', detail.value.threshold],
    ['DURATION', `${detail.value.duration_ms} ms`],
    ['DATE', new Date(detail.value.created_at).toLocaleString(locale.value.replace('_', '-'))],
    ['AGENT', detail.value.agent?.name],
  ].filter(([, value]) => value !== null && value !== undefined && value !== '');
});
onMounted(() => dialog.value.open());
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="t('CONVERSATION.KNOWLEDGE_RETRIEVAL.DETAIL_TITLE')"
    :cancel-button-label="t('CONVERSATION.KNOWLEDGE_RETRIEVAL.CLOSE')"
    :show-confirm-button="false"
    @close="emit('close')"
  >
    <div class="max-h-96 overflow-y-auto min-w-0 text-sm">
      <p v-if="loading" role="status" class="text-n-slate-11">
        {{ t('CONVERSATION.KNOWLEDGE_RETRIEVAL.LOADING') }}
      </p>
      <div v-else-if="error" role="alert">
        <p class="text-n-ruby-11">{{ t('CONVERSATION.KNOWLEDGE_RETRIEVAL.DETAIL_ERROR') }}</p>
        <Button :label="t('CONVERSATION.KNOWLEDGE_RETRIEVAL.RETRY')" variant="faded" type="button" @click="attempt += 1" />
      </div>
      <div v-else-if="detail" class="flex flex-col gap-5">
        <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4 m-0">
          <div v-for="[label, value] in fields" :key="label" class="min-w-0">
            <dt class="text-n-slate-11">{{ t(`CONVERSATION.KNOWLEDGE_RETRIEVAL.${label}`) }}</dt>
            <dd class="m-0 break-words text-n-slate-12">{{ value }}</dd>
          </div>
        </dl>
        <section class="min-w-0">
          <h4 class="text-sm font-medium text-n-slate-12">{{ t('CONVERSATION.KNOWLEDGE_RETRIEVAL.USED_CHUNKS') }}</h4>
          <div class="mt-3 flex flex-col gap-3">
            <article v-for="chunk in detail.chunks" :key="chunk.id" class="min-w-0 rounded-lg bg-n-alpha-2 p-3">
              <p class="m-0 text-xs text-n-slate-11">#{{ chunk.rank }} · {{ chunk.document }} · {{ chunk.base }} · {{ chunk.score }}</p>
              <p class="mt-2 mb-0 whitespace-pre-wrap break-words text-n-slate-12">{{ chunk.content }}</p>
            </article>
          </div>
        </section>
      </div>
    </div>
  </Dialog>
</template>
