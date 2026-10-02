<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI, stagesAPI } from 'dashboard/api/crm';

const { t } = useI18n();
const pipelines = ref([]);
const name = ref('');
const stageNames = ref(t('CRM.DEFAULT_STAGES'));
const load = async () => {
  pipelines.value = (await pipelinesAPI.get()).data;
};
const create = async () => {
  const pipeline = (
    await pipelinesAPI.create({ pipeline: { name: name.value } })
  ).data;
  const stages = stageNames.value
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
  await stages.reduce(
    (previous, stage, position) =>
      previous.then(() =>
        stagesAPI(pipeline.id).create({
          pipeline_stage: { name: stage, position },
        })
      ),
    Promise.resolve()
  );
  name.value = '';
  await load();
};
const toggle = async pipeline => {
  await pipelinesAPI.update(pipeline.id, {
    pipeline: { active: !pipeline.active },
  });
  await load();
};
onMounted(load);
</script>

<template>
  <main class="p-6 bg-n-background">
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ $t('CRM.PIPELINES_TITLE') }}
      </h1>
    </div>
    <form
      class="flex flex-wrap items-end gap-3 p-4 mb-6 rounded-xl bg-n-alpha-2"
      @submit.prevent="create"
    >
      <Input v-model="name" :label="$t('CRM.PIPELINE_NAME')" required /><Input
        v-model="stageNames"
        :label="$t('CRM.STAGES')"
      /><Button type="submit" :label="$t('CRM.CREATE_PIPELINE')" />
    </form>
    <div class="grid gap-3">
      <div
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        class="flex items-center justify-between p-4 rounded-xl bg-n-alpha-2"
      >
        <div>
          <p class="font-medium text-n-slate-12">{{ pipeline.name }}</p>
          <p class="text-sm text-n-slate-11">
            {{ pipeline.stages?.length || 0 }}
            {{ $t('CRM.STAGES').toLowerCase() }}
          </p>
        </div>
        <Button
          variant="faded"
          :label="pipeline.active ? $t('CRM.DEACTIVATE') : $t('CRM.ACTIVATE')"
          @click="toggle(pipeline)"
        />
      </div>
    </div>
  </main>
</template>
