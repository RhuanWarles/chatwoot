<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { pipelinesAPI, stagesAPI, dealsAPI } from 'dashboard/api/crm';

const { t } = useI18n();
const pipelines = ref([]);
const editor = ref(null);
const confirmation = ref(null);
const draft = ref({ name: '', active: true, stages: [] });
const removedStages = ref([]);
const pendingRemoval = ref(null);
const stageCounts = ref({});
const pipelineDeals = ref([]);
const destination = ref(null);
const plannedMoves = ref([]);
const destinationOptions = computed(() =>
  draft.value.stages
    .filter(stage => stage.key !== pendingRemoval.value?.key)
    .map(stage => ({ value: stage.key, label: stage.name }))
);
const occupied = computed(
  () => stageCounts.value[pendingRemoval.value?.id] || 0
);
const saving = ref(false);
const error = ref('');
const loading = ref(true);
const toggling = ref(null);
const validProbability = probability =>
  probability == null ||
  probability === '' ||
  (Number.isInteger(probability) && probability >= 0 && probability <= 100);
const valid = computed(
  () =>
    draft.value.name.trim() &&
    draft.value.stages.length &&
    draft.value.stages.every(
      stage => stage.name.trim() && validProbability(stage.probability)
    )
);
const load = async () => {
  try {
    pipelines.value = (await pipelinesAPI.get()).data;
  } catch {
    error.value = t('CRM.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};
const openEditor = async pipeline => {
  error.value = '';
  removedStages.value = [];
  plannedMoves.value = [];
  pipelineDeals.value = [];
  draft.value = pipeline
    ? {
        ...pipeline,
        stages: pipeline.stages.map(stage => ({
          ...stage,
          key: crypto.randomUUID(),
        })),
      }
    : {
        name: '',
        active: true,
        stages: [{ name: '', probability: null, key: crypto.randomUUID() }],
      };
  stageCounts.value = {};
  if (pipeline) {
    try {
      const { data } = await dealsAPI.get();
      pipelineDeals.value = data.filter(
        deal => deal.pipeline_id === pipeline.id
      );
      pipelineDeals.value.forEach(deal => {
        stageCounts.value[deal.pipeline_stage_id] =
          (stageCounts.value[deal.pipeline_stage_id] || 0) + 1;
      });
    } catch {
      error.value = t('CRM.LOAD_ERROR');
      return;
    }
  }
  editor.value.open();
};
const addStage = () => {
  draft.value.stages.push({
    name: '',
    probability: null,
    key: crypto.randomUUID(),
  });
};
const requestRemoval = stage => {
  pendingRemoval.value = stage;
  destination.value = null;
  confirmation.value.open();
};
const confirmRemoval = () => {
  const stage = pendingRemoval.value;
  if (occupied.value && !destination.value) return;
  if (plannedMoves.value.some(move => move.destination === stage.key)) {
    error.value = t('CRM.MOVE_DESTINATION_REMOVED');
    confirmation.value.close();
    return;
  }
  if (occupied.value) {
    plannedMoves.value.push(
      ...pipelineDeals.value
        .filter(deal => deal.pipeline_stage_id === stage.id)
        .map(deal => ({ dealId: deal.id, destination: destination.value }))
    );
  }
  if (stage.id) removedStages.value.push(stage);
  draft.value.stages = draft.value.stages.filter(
    item => item.key !== stage.key
  );
  confirmation.value.close();
};
const save = async () => {
  if (!valid.value || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      pipeline: { name: draft.value.name.trim(), active: draft.value.active },
    };
    if (draft.value.id) {
      await pipelinesAPI.update(draft.value.id, payload);
    } else {
      draft.value.id = (await pipelinesAPI.create(payload)).data.id;
    }
    const api = stagesAPI(draft.value.id);
    await draft.value.stages.reduce(async (previous, stage) => {
      await previous;
      const stagePayload = {
        pipeline_stage: {
          name: stage.name.trim(),
          probability:
            stage.probability == null || stage.probability === ''
              ? null
              : stage.probability,
        },
      };
      if (stage.id) {
        await api.update(stage.id, stagePayload);
      } else {
        stage.id = (await api.create(stagePayload)).data.id;
      }
    }, Promise.resolve());
    await plannedMoves.value.slice().reduce(async (previous, move) => {
      await previous;
      const target = draft.value.stages.find(
        stage => stage.key === move.destination
      );
      await dealsAPI.update(move.dealId, {
        deal: { pipeline_stage_id: target.id },
      });
      plannedMoves.value = plannedMoves.value.filter(
        item => item.dealId !== move.dealId
      );
    }, Promise.resolve());
    await removedStages.value.slice().reduce(async (previous, stage) => {
      await previous;
      await api.delete(stage.id);
      removedStages.value = removedStages.value.filter(
        item => item.id !== stage.id
      );
    }, Promise.resolve());
    await pipelinesAPI.reorderStages(
      draft.value.id,
      draft.value.stages.map(stage => stage.id)
    );
    editor.value.close();
    await load();
  } catch {
    error.value = t('CRM.SAVE_ERROR');
  } finally {
    saving.value = false;
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
        :label="t('CRM.NEW_PIPELINE')"
        icon="i-lucide-plus"
        @click="openEditor()"
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
      <Button :label="t('CRM.CREATE_PIPELINE')" @click="openEditor()" />
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
        <div class="flex flex-wrap justify-between gap-2 pt-2">
          <Button
            variant="faded"
            color="slate"
            icon="i-lucide-pencil"
            :label="t('CRM.EDIT_PIPELINE')"
            @click="openEditor(pipeline)"
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
    <Dialog
      ref="editor"
      width="5xl"
      overflow-y-auto
      :title="draft.id ? t('CRM.EDIT_PIPELINE') : t('CRM.NEW_PIPELINE')"
      :confirm-button-label="
        draft.id ? t('CRM.SAVE_CHANGES') : t('CRM.CREATE_PIPELINE')
      "
      :cancel-button-label="t('CRM.CANCEL')"
      :disable-confirm-button="!valid"
      :is-loading="saving"
      @confirm="save"
      @close="load"
    >
      <fieldset :disabled="saving" class="flex flex-col min-w-0 gap-4">
        <Input v-model="draft.name" :label="t('CRM.PIPELINE_NAME')" />
        <label class="flex items-center gap-2 text-sm text-n-slate-12"
          ><input
            v-model="draft.active"
            type="checkbox"
            class="accent-blue-600"
          />{{ t('CRM.ACTIVE') }}</label
        >
        <div>
          <h3 class="mb-1 text-sm font-semibold text-n-slate-12">
            {{ t('CRM.STAGES') }}
          </h3>
          <p class="mb-3 text-sm text-n-slate-11">
            {{ t('CRM.REORDER_HELP') }}
          </p>
          <Draggable
            v-model="draft.stages"
            item-key="key"
            handle=".stage-handle"
            :disabled="saving"
            class="flex gap-3 overflow-x-auto pb-3"
          >
            <template #item="{ element, index }">
              <div
                class="flex flex-col flex-shrink-0 w-64 gap-3 p-4 border border-n-weak rounded-lg bg-n-background"
              >
                <Button
                  type="button"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-grip-vertical"
                  class="stage-handle shrink-0 cursor-grab self-start"
                  :aria-label="t('CRM.REORDER_STAGE')"
                />
                <Input
                  v-model="element.name"
                  class="flex-1 min-w-0"
                  :label="t('CRM.STAGE_NUMBER', { number: index + 1 })"
                />
                <Input
                  v-model="element.probability"
                  type="number"
                  min="0"
                  max="100"
                  :label="t('CRM.PROBABILITY')"
                  :placeholder="t('CRM.PROBABILITY_OPTIONAL')"
                  :message="
                    validProbability(element.probability)
                      ? ''
                      : t('CRM.PROBABILITY_INVALID')
                  "
                  :message-type="
                    validProbability(element.probability) ? 'info' : 'error'
                  "
                  @input="
                    event => {
                      if (event.target.value === '') element.probability = null;
                    }
                  "
                />
                <Button
                  type="button"
                  variant="ghost"
                  color="ruby"
                  icon="i-lucide-trash-2"
                  :aria-label="t('CRM.DELETE_STAGE')"
                  @click="requestRemoval(element)"
                />
              </div>
            </template>
          </Draggable>
        </div>
        <Button
          type="button"
          variant="faded"
          color="slate"
          icon="i-lucide-plus"
          :label="t('CRM.ADD_STAGE')"
          @click="addStage"
        />
        <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
          {{ error }}
        </p>
      </fieldset>
    </Dialog>
    <Dialog
      ref="confirmation"
      type="alert"
      :title="t('CRM.DELETE_STAGE')"
      :description="
        pendingRemoval && stageCounts[pendingRemoval.id]
          ? t('CRM.OCCUPIED_STAGE', { count: stageCounts[pendingRemoval.id] })
          : t('CRM.DELETE_STAGE_CONFIRM')
      "
      :disable-confirm-button="Boolean(occupied && !destination)"
      :confirm-button-label="t('CRM.DELETE_STAGE')"
      :cancel-button-label="t('CRM.CANCEL')"
      @confirm="confirmRemoval"
    >
      <p
        v-if="stageCounts[pendingRemoval?.id]"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('CRM.MOVE_DEALS_ON_SAVE') }}
      </p>
      <ComboBox
        v-if="occupied"
        v-model="destination"
        :options="destinationOptions"
        :placeholder="t('CRM.MOVE_DESTINATION')"
      />
    </Dialog>
  </main>
</template>
