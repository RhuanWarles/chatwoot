<script setup>
import { computed, ref, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import CreateAssistantDialog from './pageComponents/assistant/CreateAssistantDialog.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const assistants = useMapGetter('captainAssistants/getRecords');
const query = ref('');
const dialog = ref(null);

const filteredAssistants = computed(() => {
  const value = query.value.trim().toLowerCase();
  if (!value) return assistants.value;
  return assistants.value.filter(assistant =>
    [assistant.name, assistant.description].some(text =>
      String(text || '').toLowerCase().includes(value)
    )
  );
});

const openAssistant = assistant => {
  const currentName = [
    'captain_assistants_index',
    'captain_assistants_overview_index',
  ].includes(route.name)
    ? 'captain_assistants_settings_index'
    : route.name;
  router.push({
    name: currentName || 'captain_assistants_settings_index',
    params: { ...route.params, assistantId: assistant.id },
  });
};

const openCreate = () => nextTick(() => dialog.value?.dialogRef.open());
const onCreated = assistant => {
  if (assistant?.id) openAssistant(assistant);
};
</script>

<template>
  <aside
    class="hidden lg:flex flex-col w-72 shrink-0 border-e border-n-weak bg-n-solid-2"
  >
    <div
      class="flex items-center justify-between gap-2 px-4 py-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-2 min-w-0">
        <h2 class="text-sm font-semibold truncate text-n-slate-12">
          {{ t('CAPTAIN.WORKSPACE.ASSISTANTS') }}
        </h2>
        <span class="text-xs text-n-slate-10">{{ assistants.length }}</span>
      </div>
      <Button
        icon="i-lucide-plus"
        size="xs"
        slate
        ghost
        :aria-label="t('CAPTAIN.WORKSPACE.CREATE_ASSISTANT')"
        @click="openCreate"
      />
    </div>
    <div class="p-3 border-b border-n-weak">
      <div class="relative">
        <span class="absolute top-2.5 start-3 i-lucide-search text-n-slate-10" aria-hidden="true" />
        <Input
          v-model="query"
          custom-input-class="ps-9"
          :placeholder="t('CAPTAIN.WORKSPACE.SEARCH_ASSISTANTS')"
        />
      </div>
    </div>
    <div class="flex-1 min-h-0 p-2 space-y-1 overflow-y-auto">
      <button
        v-for="assistant in filteredAssistants"
        :key="assistant.id"
        type="button"
        class="flex items-center w-full gap-3 px-3 py-2 text-start rounded-lg transition-colors"
        :class="Number(route.params.assistantId) === assistant.id ? 'bg-n-alpha-2 outline outline-1 outline-n-weak' : 'hover:bg-n-alpha-2'"
        @click="openAssistant(assistant)"
      >
        <Avatar :name="assistant.name" :size="28" icon-name="i-lucide-bot" rounded-full />
        <span class="min-w-0">
          <span class="block text-sm font-medium truncate text-n-slate-12">{{ assistant.name }}</span>
          <span class="block text-xs truncate text-n-slate-10">
            {{ assistant.active ? t('CAPTAIN.WORKSPACE.ACTIVE') : t('CAPTAIN.WORKSPACE.INACTIVE') }}
          </span>
        </span>
      </button>
      <p v-if="!filteredAssistants.length" class="px-3 py-8 text-sm text-center text-n-slate-10">
        {{ t('CAPTAIN.WORKSPACE.EMPTY_ASSISTANTS') }}
      </p>
    </div>
  </aside>
  <CreateAssistantDialog ref="dialog" type="create" @created="onCreated" />
</template>
