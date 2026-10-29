<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  active: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  isDirty: { type: Boolean, default: false },
  isSaved: { type: Boolean, default: false },
  hasWebhook: { type: Boolean, default: false },
  issueCount: { type: Number, default: 0 },
  issueHint: { type: String, default: '' },
});

const emit = defineEmits([
  'back',
  'save',
  'test',
  'history',
  'copyWebhook',
  'toggleActive',
]);

const { t } = useI18n();

const name = defineModel('name', { type: String, default: '' });
const description = defineModel('description', { type: String, default: '' });
</script>

<template>
  <div class="flex flex-wrap items-center gap-3 pb-3 border-b border-n-weak">
    <Button
      ghost
      slate
      sm
      icon="i-lucide-arrow-left"
      :aria-label="t('AUTOMATION.WORKFLOWS.EDITOR.BACK')"
      @click="emit('back')"
    />
    <div class="w-64 min-w-0">
      <Input
        v-model="name"
        size="sm"
        :placeholder="t('AUTOMATION.WORKFLOWS.EDITOR.NAME_PLACEHOLDER')"
      />
    </div>
    <div class="flex-1 hidden min-w-0 max-w-md lg:block">
      <Input
        v-model="description"
        size="sm"
        :placeholder="t('AUTOMATION.WORKFLOWS.EDITOR.DESCRIPTION_PLACEHOLDER')"
      />
    </div>
    <div class="flex items-center gap-2 ms-auto">
      <span
        v-if="issueCount"
        v-tooltip.bottom="issueHint"
        class="px-2 py-1 text-xs rounded-md bg-n-ruby-3 text-n-ruby-11"
      >
        {{ t('AUTOMATION.WORKFLOWS.EDITOR.ISSUES', { n: issueCount }) }}
      </span>
      <span v-else-if="isDirty" class="text-xs text-n-slate-10">
        {{ t('AUTOMATION.WORKFLOWS.EDITOR.UNSAVED') }}
      </span>
      <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
        <Switch
          :model-value="active"
          @update:model-value="emit('toggleActive', $event)"
        />
        {{ t('AUTOMATION.WORKFLOWS.EDITOR.ACTIVE') }}
      </label>
      <Button
        v-if="hasWebhook && isSaved"
        faded
        slate
        sm
        icon="i-lucide-link"
        :label="t('AUTOMATION.WORKFLOWS.EDITOR.COPY_WEBHOOK')"
        @click="emit('copyWebhook')"
      />
      <Button
        v-if="isSaved"
        faded
        slate
        sm
        icon="i-lucide-history"
        :label="t('AUTOMATION.WORKFLOWS.EDITOR.HISTORY')"
        @click="emit('history')"
      />
      <Button
        v-if="isSaved"
        faded
        slate
        sm
        icon="i-lucide-play"
        :label="t('AUTOMATION.WORKFLOWS.EDITOR.TEST')"
        @click="emit('test')"
      />
      <Button
        sm
        icon="i-lucide-save"
        :label="t('AUTOMATION.WORKFLOWS.EDITOR.SAVE')"
        :is-loading="isSaving"
        @click="emit('save')"
      />
    </div>
  </div>
</template>
