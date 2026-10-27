<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import {
  customFieldsAPI,
  pipelinesAPI,
  stagesAPI,
  dealsAPI,
} from 'dashboard/api/crm';
import CrmAutomationsPanel from './CrmAutomationsPanel.vue';
import {
  TRIGGERS,
  cloneAutomations,
  isAutomationValid,
  serializeAutomations,
} from './automationHelpers';

const emit = defineEmits(['saved', 'closed']);
const { t } = useI18n();
const DEFAULT_STAGE_KEYS = [
  'CRM.DEFAULT_STAGE_NEW_LEAD',
  'CRM.DEFAULT_STAGE_QUALIFICATION',
  'CRM.DEFAULT_STAGE_PROPOSAL',
  'CRM.DEFAULT_STAGE_NEGOTIATION',
  'CRM.DEFAULT_STAGE_CLOSED',
];
const MAX_VISIBLE_ISSUES = 3;
const editor = ref(null);
const confirmation = ref(null);
const draft = ref({
  name: '',
  active: true,
  won_automations: [],
  lost_automations: [],
  field_automations: [],
  stages: [],
});
const customFields = ref(null);
const activeTab = ref('stages');
const selectedTrigger = ref('');
const pipelines = ref([]);
const destinationsReady = ref(false);
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
const loading = ref(false);
const stageCountsReady = ref(false);
const error = ref('');
const validProbability = probability =>
  probability == null ||
  probability === '' ||
  (Number.isInteger(probability) && probability >= 0 && probability <= 100);
const stageLabel = (stage, index) =>
  stage.name.trim() || t('CRM.STAGE_NUMBER', { number: index + 1 });
const destinationPipelines = computed(() =>
  pipelines.value.map(pipeline =>
    pipeline.id === draft.value.id
      ? {
          ...pipeline,
          stages: draft.value.stages
            .filter(stage => stage.id)
            .map(stage => ({ id: stage.id, name: stage.name })),
        }
      : pipeline
  )
);
const validationContext = computed(() => ({
  destinations: destinationsReady.value ? destinationPipelines.value : null,
  fields: customFields.value,
}));
const hasAutomationIssue = actions =>
  actions.some(action => !isAutomationValid(action, validationContext.value));
const automationTotal = computed(
  () =>
    draft.value.stages.reduce(
      (total, stage) => total + stage.automations.length,
      0
    ) +
    draft.value.won_automations.length +
    draft.value.lost_automations.length +
    draft.value.field_automations.length
);
const tabItems = computed(() => [
  { key: 'stages', label: t('CRM.STAGES'), count: draft.value.stages.length },
  {
    key: 'automations',
    label: t('CRM.PIPELINE_TAB_AUTOMATIONS'),
    count: automationTotal.value,
  },
]);
const activeTabIndex = computed(() =>
  tabItems.value.findIndex(tab => tab.key === activeTab.value)
);
const outcomes = computed(() => [
  {
    kind: 'won',
    label: t('CRM.STATUS_WON'),
    actions: draft.value.won_automations,
  },
  {
    kind: 'lost',
    label: t('CRM.STATUS_LOST'),
    actions: draft.value.lost_automations,
  },
]);
const issues = computed(() => {
  const list = [];
  const { name, stages } = draft.value;
  if (!name.trim()) {
    list.push({
      id: 'pipeline-name',
      tab: 'stages',
      message: t('CRM.ISSUE_PIPELINE_NAME'),
    });
  }
  if (!stages.length) {
    list.push({
      id: 'no-stages',
      tab: 'stages',
      message: t('CRM.ISSUE_NO_STAGES'),
    });
  }
  stages.forEach((stage, index) => {
    if (!stage.name.trim()) {
      list.push({
        id: `stage-name-${stage.key}`,
        tab: 'stages',
        message: t('CRM.ISSUE_STAGE_NAME', { number: index + 1 }),
      });
    }
    if (!validProbability(stage.probability)) {
      list.push({
        id: `stage-probability-${stage.key}`,
        tab: 'stages',
        message: t('CRM.ISSUE_STAGE_PROBABILITY', {
          stage: stageLabel(stage, index),
        }),
      });
    }
  });
  const addAutomationIssues = (actions, trigger, label) =>
    actions.forEach((action, actionIndex) => {
      if (isAutomationValid(action, validationContext.value)) return;
      list.push({
        id: action.key,
        tab: 'automations',
        trigger,
        message: t('CRM.ISSUE_AUTOMATION', {
          trigger: label,
          number: actionIndex + 1,
        }),
      });
    });
  stages.forEach((stage, index) =>
    addAutomationIssues(
      stage.automations,
      `stage:${stage.key}`,
      stageLabel(stage, index)
    )
  );
  addAutomationIssues(
    draft.value.won_automations,
    'won',
    t(TRIGGERS.won.railKey)
  );
  addAutomationIssues(
    draft.value.lost_automations,
    'lost',
    t(TRIGGERS.lost.railKey)
  );
  addAutomationIssues(
    draft.value.field_automations,
    'field',
    t(TRIGGERS.field.railKey)
  );
  return list;
});
const valid = computed(
  () => stageCountsReady.value && issues.value.length === 0
);
const goToIssue = ({ tab, trigger }) => {
  if (trigger) selectedTrigger.value = trigger;
  activeTab.value = tab;
};
const openAutomations = trigger => goToIssue({ tab: 'automations', trigger });
const loadDestinations = async () => {
  try {
    pipelines.value = (await pipelinesAPI.get()).data;
    destinationsReady.value = true;
    customFields.value = (await customFieldsAPI.get()).data.filter(
      field => field.active
    );
  } catch {
    error.value = t('CRM.LOAD_ERROR');
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
        won_automations: cloneAutomations(pipeline.won_automations),
        lost_automations: cloneAutomations(pipeline.lost_automations),
        field_automations: cloneAutomations(pipeline.field_automations),
        stages: pipeline.stages.map(stage => ({
          ...stage,
          automations: cloneAutomations(stage.automations),
          key: crypto.randomUUID(),
        })),
      }
    : {
        name: '',
        active: true,
        won_automations: [],
        lost_automations: [],
        field_automations: [],
        stages: DEFAULT_STAGE_KEYS.map(label => ({
          name: t(label),
          probability: null,
          ai_instructions: null,
          automations: [],
          key: crypto.randomUUID(),
        })),
      };
  activeTab.value = 'stages';
  selectedTrigger.value = draft.value.stages[0]
    ? `stage:${draft.value.stages[0].key}`
    : '';
  pipelines.value = [];
  customFields.value = null;
  destinationsReady.value = false;
  stageCounts.value = {};
  stageCountsReady.value = !pipeline;
  editor.value.open();
  loadDestinations();
  if (pipeline) {
    loading.value = true;
    try {
      const { data } = await dealsAPI.get({
        params: { pipeline_id: pipeline.id },
      });
      pipelineDeals.value = data.filter(
        deal => deal.pipeline_id === pipeline.id
      );
      pipelineDeals.value.forEach(deal => {
        stageCounts.value[deal.pipeline_stage_id] =
          (stageCounts.value[deal.pipeline_stage_id] || 0) + 1;
      });
      stageCountsReady.value = true;
    } catch {
      error.value = t('CRM.LOAD_ERROR');
    } finally {
      loading.value = false;
    }
  }
};
const addStage = () => {
  draft.value.stages.push({
    name: '',
    probability: null,
    ai_instructions: null,
    automations: [],
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
  let failure = { key: 'CRM.SAVE_ERROR' };
  try {
    failure = { key: 'CRM.SAVE_ERROR_PIPELINE' };
    const payload = {
      pipeline: {
        name: draft.value.name.trim(),
        active: draft.value.active,
        won_automations: serializeAutomations(draft.value.won_automations),
        lost_automations: serializeAutomations(draft.value.lost_automations),
        field_automations: serializeAutomations(draft.value.field_automations),
      },
    };
    if (draft.value.id) {
      await pipelinesAPI.update(draft.value.id, payload);
    } else {
      draft.value.id = (await pipelinesAPI.create(payload)).data.id;
    }
    const api = stagesAPI(draft.value.id);
    await draft.value.stages.reduce(async (previous, stage) => {
      await previous;
      failure = {
        key: 'CRM.SAVE_ERROR_STAGE',
        params: { stage: stage.name.trim() },
      };
      const stagePayload = {
        pipeline_stage: {
          name: stage.name.trim(),
          probability:
            stage.probability == null || stage.probability === ''
              ? null
              : stage.probability,
          ai_instructions: stage.ai_instructions?.trim() || null,
          automations: serializeAutomations(stage.automations),
        },
      };
      if (stage.id) {
        await api.update(stage.id, stagePayload);
      } else {
        stage.id = (await api.create(stagePayload)).data.id;
      }
    }, Promise.resolve());
    failure = { key: 'CRM.SAVE_ERROR' };
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
    emit('saved', draft.value.id);
    editor.value.close();
  } catch {
    error.value = t(failure.key, failure.params);
  } finally {
    saving.value = false;
  }
};
defineExpose({ open: openEditor });
</script>

<template>
  <Dialog
    ref="editor"
    width="5xl"
    overflow-y-auto
    :title="draft.id ? t('CRM.EDIT_PIPELINE') : t('CRM.NEW_PIPELINE')"
    :description="t('CRM.PIPELINE_EDITOR_HELP')"
    :confirm-button-label="
      draft.id ? t('CRM.SAVE_CHANGES') : t('CRM.CREATE_PIPELINE')
    "
    :cancel-button-label="t('CRM.CANCEL')"
    :disable-confirm-button="!valid"
    :is-loading="saving || loading"
    @confirm="save"
    @close="!saving && emit('closed')"
  >
    <fieldset
      :disabled="saving || !stageCountsReady"
      class="flex min-w-0 flex-col gap-5"
    >
      <div class="grid items-end gap-4 md:grid-cols-[1fr_auto]">
        <Input v-model="draft.name" :label="t('CRM.PIPELINE_NAME')" />
        <label class="flex items-center gap-2 pb-2.5 text-sm text-n-slate-12">
          <input
            v-model="draft.active"
            type="checkbox"
            class="accent-blue-600"
          />
          {{ t('CRM.ACTIVE') }}
        </label>
      </div>
      <TabBar
        :tabs="tabItems"
        :initial-active-tab="activeTabIndex"
        @tab-changed="tab => (activeTab = tab.key)"
      />
      <div class="flex flex-col gap-5 md:min-h-[28rem]">
        <template v-if="activeTab === 'stages'">
          <div class="flex flex-col gap-3">
            <p class="m-0 text-sm text-n-slate-11">
              {{ t('CRM.REORDER_HELP') }}
            </p>
            <Draggable
              v-model="draft.stages"
              item-key="key"
              handle=".stage-handle"
              :disabled="saving"
              class="flex flex-col gap-3"
            >
              <template #item="{ element, index }">
                <div
                  class="flex flex-wrap items-end gap-3 rounded-xl border border-n-container bg-n-surface-1 p-3 shadow-sm md:flex-nowrap"
                >
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    icon="i-lucide-grip-vertical"
                    class="stage-handle shrink-0 cursor-grab"
                    :aria-label="t('CRM.REORDER_STAGE')"
                  />
                  <div class="flex-1 basis-48 min-w-0">
                    <Input
                      v-model="element.name"
                      :label="t('CRM.STAGE_NUMBER', { number: index + 1 })"
                    />
                  </div>
                  <div class="w-full md:w-44">
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
                          if (event.target.value === '')
                            element.probability = null;
                        }
                      "
                    />
                  </div>
                  <Button
                    type="button"
                    variant="faded"
                    :color="
                      hasAutomationIssue(element.automations) ? 'ruby' : 'slate'
                    "
                    :icon="
                      hasAutomationIssue(element.automations)
                        ? 'i-lucide-triangle-alert'
                        : 'i-lucide-zap'
                    "
                    :title="
                      hasAutomationIssue(element.automations)
                        ? t('CRM.AUTOMATION_NEEDS_REVIEW')
                        : undefined
                    "
                    @click="openAutomations(`stage:${element.key}`)"
                  >
                    <span class="min-w-0 truncate">
                      {{
                        t('CRM.AUTOMATION_COUNT', element.automations.length)
                      }}
                    </span>
                    <span class="sr-only">
                      {{
                        t('CRM.AUTOMATION_FOR_TRIGGER', {
                          trigger: stageLabel(element, index),
                        })
                      }}
                    </span>
                  </Button>
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
            <Button
              type="button"
              variant="faded"
              color="slate"
              icon="i-lucide-plus"
              :label="t('CRM.ADD_STAGE')"
              @click="addStage"
            />
          </div>
          <section class="flex flex-col gap-3">
            <div>
              <h3 class="m-0 text-heading-2 text-n-slate-12">
                {{ t('CRM.CLOSING_TITLE') }}
              </h3>
              <p class="m-0 mt-1 text-body-main text-n-slate-11">
                {{ t('CRM.CLOSING_HELP') }}
              </p>
            </div>
            <div class="grid gap-3 md:grid-cols-2">
              <div
                v-for="outcome in outcomes"
                :key="outcome.kind"
                class="flex items-center gap-3 rounded-xl border border-n-container bg-n-surface-1 p-3 shadow-sm"
              >
                <span
                  class="grid size-9 shrink-0 place-items-center rounded-lg"
                  :class="TRIGGERS[outcome.kind].badgeClass"
                >
                  <Icon :icon="TRIGGERS[outcome.kind].icon" class="size-5" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="m-0 text-heading-3 text-n-slate-12">
                    {{ outcome.label }}
                  </p>
                  <p class="m-0 text-body-main text-n-slate-11">
                    {{ t(TRIGGERS[outcome.kind].descriptionKey) }}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="faded"
                  :color="
                    hasAutomationIssue(outcome.actions) ? 'ruby' : 'slate'
                  "
                  :icon="
                    hasAutomationIssue(outcome.actions)
                      ? 'i-lucide-triangle-alert'
                      : 'i-lucide-zap'
                  "
                  :title="
                    hasAutomationIssue(outcome.actions)
                      ? t('CRM.AUTOMATION_NEEDS_REVIEW')
                      : undefined
                  "
                  @click="openAutomations(outcome.kind)"
                >
                  <span class="min-w-0 truncate">
                    {{ t('CRM.AUTOMATION_COUNT', outcome.actions.length) }}
                  </span>
                  <span class="sr-only">
                    {{
                      t('CRM.AUTOMATION_FOR_TRIGGER', {
                        trigger: outcome.label,
                      })
                    }}
                  </span>
                </Button>
              </div>
            </div>
          </section>
        </template>
        <CrmAutomationsPanel
          v-else
          v-model:stages="draft.stages"
          v-model:won="draft.won_automations"
          v-model:lost="draft.lost_automations"
          v-model:field="draft.field_automations"
          v-model:selected="selectedTrigger"
          :destinations="destinationsReady ? destinationPipelines : null"
          :custom-fields="customFields"
        />
      </div>
      <div
        v-if="issues.length"
        role="status"
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-amber-2 outline outline-1 outline-n-amber-4"
      >
        <p class="m-0 text-heading-3 text-n-amber-11">
          {{ t('CRM.ISSUES_TITLE') }}
        </p>
        <ul class="flex flex-col gap-1 p-0 m-0 list-none">
          <li
            v-for="issue in issues.slice(0, MAX_VISIBLE_ISSUES)"
            :key="issue.id"
          >
            <button
              type="button"
              class="p-0 text-start text-body-main text-n-amber-11 hover:underline focus-visible:underline"
              @click="goToIssue(issue)"
            >
              {{ issue.message }}
            </button>
          </li>
        </ul>
        <p
          v-if="issues.length > MAX_VISIBLE_ISSUES"
          class="m-0 text-label-small text-n-amber-11"
        >
          {{
            t('CRM.ISSUES_MORE', { count: issues.length - MAX_VISIBLE_ISSUES })
          }}
        </p>
      </div>
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
</template>
