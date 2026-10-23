<script setup>
import { computed, onMounted, provide, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CrmAutomationList from './CrmAutomationList.vue';
import {
  DESTINATIONS_KEY,
  TRIGGERS,
  isAutomationValid,
} from './automationHelpers';

const props = defineProps({
  destinations: { type: Array, default: null },
});
const stages = defineModel('stages', { type: Array, required: true });
const won = defineModel('won', { type: Array, required: true });
const lost = defineModel('lost', { type: Array, required: true });
const selected = defineModel('selected', { type: String, default: '' });

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

provide(DESTINATIONS_KEY, toRef(props, 'destinations'));

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
});

const triggers = computed(() => [
  ...stages.value.map((stage, index) => ({
    key: `stage:${stage.key}`,
    kind: 'stage',
    name: stage.name.trim() || t('CRM.STAGE_NUMBER', { number: index + 1 }),
    automations: stage.automations,
  })),
  {
    key: 'won',
    kind: 'won',
    name: t(TRIGGERS.won.railKey),
    automations: won.value,
  },
  {
    key: 'lost',
    kind: 'lost',
    name: t(TRIGGERS.lost.railKey),
    automations: lost.value,
  },
]);
const railGroups = computed(() => [
  {
    id: 'stages',
    title: t('CRM.AUTOMATION_GROUP_STAGES'),
    items: triggers.value.filter(({ kind }) => kind === 'stage'),
  },
  {
    id: 'closing',
    title: t('CRM.AUTOMATION_GROUP_CLOSING'),
    items: triggers.value.filter(({ kind }) => kind !== 'stage'),
  },
]);
const current = computed(
  () =>
    triggers.value.find(({ key }) => key === selected.value) ||
    triggers.value[0]
);
const currentStage = computed(() =>
  stages.value.find(stage => `stage:${stage.key}` === current.value.key)
);
const currentAutomations = computed({
  get: () => current.value.automations,
  set: value => {
    if (current.value.kind === 'won') won.value = value;
    else if (current.value.kind === 'lost') lost.value = value;
    else currentStage.value.automations = value;
  },
});
const currentAiInstructions = computed({
  get: () => currentStage.value?.ai_instructions,
  set: value => {
    currentStage.value.ai_instructions = value;
  },
});

const hasIssue = item =>
  item.automations.some(
    action => !isAutomationValid(action, { destinations: props.destinations })
  );
const preventImplicitSubmit = event => {
  if (event.target instanceof HTMLInputElement) event.preventDefault();
};
</script>

<template>
  <div
    class="grid gap-4 md:grid-cols-[15rem_1fr]"
    @keydown.enter="preventImplicitSubmit"
  >
    <nav :aria-label="t('CRM.AUTOMATION_TRIGGERS')" class="flex flex-col gap-4">
      <div
        v-for="group in railGroups"
        :key="group.id"
        class="flex flex-col gap-1 min-w-0"
      >
        <h4
          class="hidden m-0 px-2.5 text-xs font-medium tracking-wide uppercase text-n-slate-11 md:block"
        >
          {{ group.title }}
        </h4>
        <ul
          class="flex gap-1 p-0 m-0 list-none overflow-x-auto no-scrollbar md:flex-col md:overflow-visible"
        >
          <li
            v-for="item in group.items"
            :key="item.key"
            class="shrink-0 md:shrink"
          >
            <button
              type="button"
              class="flex items-center w-full gap-2 px-2.5 py-2 text-sm text-start rounded-lg min-h-9 outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="
                item.key === current.key
                  ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
                  : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12'
              "
              :aria-current="item.key === current.key ? 'true' : undefined"
              @click="selected = item.key"
            >
              <Icon
                :icon="TRIGGERS[item.kind].icon"
                class="size-4 shrink-0"
                :class="TRIGGERS[item.kind].textClass"
              />
              <span class="min-w-0 flex-1 truncate">{{ item.name }}</span>
              <span
                v-if="item.automations.length || hasIssue(item)"
                class="inline-flex items-center gap-1 px-1.5 rounded-full text-label-small"
                :class="
                  hasIssue(item)
                    ? 'bg-n-ruby-3 text-n-ruby-11'
                    : 'bg-n-alpha-2 text-n-slate-11'
                "
              >
                <Icon
                  v-if="hasIssue(item)"
                  icon="i-lucide-triangle-alert"
                  class="size-3"
                />
                {{ item.automations.length }}
              </span>
            </button>
          </li>
        </ul>
      </div>
    </nav>

    <section
      class="flex flex-col gap-5 min-w-0 rounded-xl border border-n-weak bg-n-solid-1 p-4 md:p-5"
    >
      <header class="flex items-start gap-3">
        <span
          class="grid size-10 shrink-0 place-items-center rounded-xl"
          :class="TRIGGERS[current.kind].badgeClass"
        >
          <Icon :icon="TRIGGERS[current.kind].icon" class="size-5" />
        </span>
        <div class="min-w-0">
          <h3 class="m-0 text-heading-2 text-n-slate-12">
            {{ t(TRIGGERS[current.kind].titleKey, { stage: current.name }) }}
          </h3>
          <p class="m-0 mt-1 text-body-main text-n-slate-11">
            {{ t(TRIGGERS[current.kind].helpKey) }}
          </p>
        </div>
      </header>
      <CrmAutomationList
        :key="current.key"
        v-model:automations="currentAutomations"
        v-model:ai-instructions="currentAiInstructions"
        :kind="current.kind"
        :trigger-name="current.name"
      />
    </section>
  </div>
</template>
