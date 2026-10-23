<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { ACTION_GROUPS, ACTION_TYPES } from './automationHelpers';

const emit = defineEmits(['select', 'cancel']);

const { t } = useI18n();
const tiles = ref([]);

onMounted(() => tiles.value[0]?.focus());
</script>

<template>
  <section
    :aria-label="t('CRM.AUTOMATION_PICKER_TITLE')"
    class="flex flex-col gap-4 p-4 rounded-xl border border-n-weak bg-n-solid-2"
  >
    <div class="flex items-center justify-between gap-3">
      <h4 class="m-0 text-heading-3 text-n-slate-12">
        {{ t('CRM.AUTOMATION_PICKER_TITLE') }}
      </h4>
      <Button
        type="button"
        variant="ghost"
        color="slate"
        size="sm"
        :label="t('CRM.CANCEL')"
        @click="emit('cancel')"
      />
    </div>
    <div
      v-for="group in ACTION_GROUPS"
      :key="group.id"
      class="flex flex-col gap-2"
    >
      <p
        class="m-0 text-xs font-medium tracking-wide uppercase text-n-slate-11"
      >
        {{ t(group.labelKey) }}
      </p>
      <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
        <button
          v-for="type in group.types"
          :key="type"
          ref="tiles"
          type="button"
          class="flex items-start gap-3 p-3 text-start rounded-lg bg-n-solid-1 outline outline-1 outline-n-weak hover:outline-n-strong hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="emit('select', type)"
        >
          <span
            class="grid shrink-0 size-8 place-items-center rounded-lg bg-n-alpha-2 text-n-slate-11"
          >
            <Icon :icon="ACTION_TYPES[type].icon" class="size-4" />
          </span>
          <span class="flex flex-col min-w-0 gap-0.5">
            <span class="text-heading-3 text-n-slate-12">
              {{ t(ACTION_TYPES[type].labelKey) }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ t(ACTION_TYPES[type].descriptionKey) }}
            </span>
          </span>
        </button>
      </div>
    </div>
  </section>
</template>
