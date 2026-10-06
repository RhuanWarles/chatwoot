<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import Button from 'dashboard/components-next/button/Button.vue';
import CrmPipelineEditor from '../components/CrmPipelineEditor.vue';
import { pipelinesAPI } from 'dashboard/api/crm';
const { t } = useI18n();
const { isAdmin } = useAdmin();
const pipelines = ref([]);
const editor = ref(null);
const error = ref('');
const loading = ref(true);
const toggling = ref(null);
const load = async () => {
  try {
    pipelines.value = (await pipelinesAPI.get()).data;
  } catch {
    error.value = t('CRM.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const toggle = async pipeline => {
  toggling.value = pipeline.id;
  error.value = '';
  try {
    await pipelinesAPI.update(pipeline.id, {
      pipeline: { active: !pipeline.active },
    });
    await load();
  } catch {
    error.value = t('CRM.SAVE_ERROR');
  } finally {
    toggling.value = null;
  }
};
onMounted(load);
</script>

<template>
  <main
    class="flex flex-1 flex-col w-full h-full min-h-0 min-w-0 p-4 md:p-6 overflow-auto bg-n-background"
  >
    <header class="flex flex-wrap items-center justify-between gap-3 mb-5">
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('CRM.PIPELINES_TITLE') }}
      </h1>
      <Button
        v-if="isAdmin"
        :label="t('CRM.NEW_PIPELINE')"
        icon="i-lucide-plus"
        @click="editor.open()"
      />
    </header>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <div
      v-if="!loading && !pipelines.length"
      class="flex flex-col items-center justify-center flex-1 gap-3 py-12 text-center"
    >
      <h2 class="text-lg font-medium text-n-slate-12">
        {{ t('CRM.NO_PIPELINE') }}
      </h2>
      <p class="text-sm text-n-slate-11">{{ t('CRM.FIRST_PIPELINE_HELP') }}</p>
      <Button
        v-if="isAdmin"
        :label="t('CRM.CREATE_PIPELINE')"
        @click="editor.open()"
      />
    </div>
    <div class="grid gap-4">
      <article
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        class="flex flex-col gap-3 p-4 border border-n-weak rounded-xl bg-n-alpha-2"
      >
        <div class="flex items-start justify-between gap-3">
          <h2 class="min-w-0 mb-0 font-semibold text-n-slate-12 break-words">
            {{ pipeline.name }}
          </h2>
          <span
            class="px-2 py-1 rounded-md text-label-small shrink-0"
            :class="
              pipeline.active
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-slate-3 text-n-slate-11'
            "
            >{{ pipeline.active ? t('CRM.ACTIVE') : t('CRM.INACTIVE') }}</span
          >
        </div>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CRM.STAGE_COUNT', pipeline.stages.length) }}
        </p>
        <ol class="flex flex-wrap flex-1 gap-2 p-0 m-0 list-none">
          <li
            v-for="stage in pipeline.stages"
            :key="stage.id"
            class="px-2 py-1 rounded-md bg-n-background text-sm text-n-slate-11 break-words"
          >
            {{ stage.name }}
          </li>
        </ol>
        <div v-if="isAdmin" class="flex flex-wrap justify-between gap-2 pt-2">
          <Button
            variant="faded"
            color="slate"
            icon="i-lucide-pencil"
            :label="t('CRM.EDIT_PIPELINE')"
            @click="editor.open(pipeline)"
          />
          <Button
            variant="ghost"
            color="slate"
            :label="pipeline.active ? t('CRM.DEACTIVATE') : t('CRM.ACTIVATE')"
            :is-loading="toggling === pipeline.id"
            :disabled="toggling !== null"
            @click="toggle(pipeline)"
          />
        </div>
      </article>
    </div>
    <CrmPipelineEditor ref="editor" @saved="load" @closed="load" />
  </main>
</template>
