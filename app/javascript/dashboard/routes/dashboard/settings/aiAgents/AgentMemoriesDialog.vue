<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  agent: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const dialog = ref(null);
const memories = ref([]);
const loading = ref(false);
const error = ref('');

const open = async () => {
  memories.value = [];
  error.value = '';
  dialog.value.open();
  loading.value = true;
  try {
    const { data } = await aiAgentsAPI.memories(props.agent.id);
    memories.value = Array.isArray(data) ? data : [];
  } catch {
    error.value = t('AI_AGENTS.MEMORY_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const clearMemory = async memory => {
  if (loading.value) return;
  loading.value = true;
  try {
    await aiAgentsAPI.clearMemory(props.agent.id, memory.contact_id);
    memories.value = memories.value.filter(item => item.id !== memory.id);
  } catch {
    error.value = t('AI_AGENTS.MEMORY_CLEAR_ERROR');
  } finally {
    loading.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="t('AI_AGENTS.MEMORIES')"
    :cancel-button-label="t('AI_AGENTS.CLOSE')"
  >
    <div class="flex flex-col gap-3 max-h-[65vh] overflow-y-auto">
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">
        {{ error }}
      </p>
      <p v-if="loading" class="text-sm text-n-slate-11">
        {{ t('AI_AGENTS.LOADING') }}
      </p>
      <p v-else-if="!memories.length" class="text-sm text-n-slate-11">
        {{ t('AI_AGENTS.NO_MEMORIES') }}
      </p>
      <article
        v-for="memory in memories"
        :key="memory.id"
        class="p-3 rounded-lg bg-n-solid-2"
      >
        <div class="flex items-center justify-between gap-3">
          <strong class="text-sm text-n-slate-12">{{
            memory.contact_name || memory.contact_id
          }}</strong>
          <Button
            variant="ghost"
            color="ruby"
            :label="t('AI_AGENTS.CLEAR_MEMORY')"
            @click="clearMemory(memory)"
          />
        </div>
        <p class="mt-2 text-sm whitespace-pre-wrap text-n-slate-11">
          {{ memory.content }}
        </p>
      </article>
    </div>
  </Dialog>
</template>
