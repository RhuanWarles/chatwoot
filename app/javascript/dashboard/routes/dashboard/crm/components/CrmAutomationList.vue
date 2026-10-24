<script setup>
import { inject, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CrmAutomationCard from './CrmAutomationCard.vue';
import CrmAutomationField from './CrmAutomationField.vue';
import CrmAutomationForm from './CrmAutomationForm.vue';
import CrmAutomationPicker from './CrmAutomationPicker.vue';
import {
  AI_INSTRUCTIONS_MAX_LENGTH,
  DESTINATIONS_KEY,
  MAX_AUTOMATIONS,
  TRIGGERS,
  createAction,
  getActionSummary,
  isAutomationValid,
} from './automationHelpers';

const props = defineProps({
  kind: {
    type: String,
    required: true,
    validator: value => ['stage', 'won', 'lost'].includes(value),
  },
  triggerName: { type: String, default: '' },
});
const automations = defineModel('automations', {
  type: Array,
  default: () => [],
});
const aiInstructions = defineModel('aiInstructions', {
  type: String,
  default: '',
});

const { t } = useI18n();
const agents = useMapGetter('agents/getAgents');
const destinations = inject(DESTINATIONS_KEY, ref(null));
const pickerOpen = ref(false);
const justAddedKey = ref('');
const lastRemoved = ref(null);
const addButton = ref(null);
const cardRefs = {};

const add = async type => {
  const action = createAction(type, props.kind);
  justAddedKey.value = action.key;
  lastRemoved.value = null;
  automations.value = [...automations.value, action];
  pickerOpen.value = false;
  // Expand and focus only on creation, not again when the card is collapsed or restored later.
  await nextTick();
  justAddedKey.value = '';
};
const move = async (index, offset) => {
  const { key } = automations.value[index];
  const next = [...automations.value];
  [next[index], next[index + offset]] = [next[index + offset], next[index]];
  automations.value = next;
  await nextTick();
  cardRefs[key]?.focus();
};
const remove = async index => {
  lastRemoved.value = { action: automations.value[index], index };
  automations.value = automations.value.filter(
    (_, position) => position !== index
  );
  await nextTick();
  addButton.value?.$el.focus();
};
const undo = () => {
  const { action, index } = lastRemoved.value;
  const next = [...automations.value];
  next.splice(Math.min(index, next.length), 0, action);
  automations.value = next;
  lastRemoved.value = null;
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <section
      v-if="kind === 'stage'"
      class="p-4 rounded-xl border border-n-weak bg-n-solid-2"
    >
      <CrmAutomationField
        v-slot="{ id }"
        :label="t('CRM.AI_INSTRUCTIONS')"
        :hint="t('CRM.AI_INSTRUCTIONS_HELP')"
      >
        <TextArea
          :id="id"
          :model-value="aiInstructions ?? ''"
          :placeholder="t('CRM.AI_INSTRUCTIONS_PLACEHOLDER')"
          :max-length="AI_INSTRUCTIONS_MAX_LENGTH"
          show-character-count
          auto-height
          min-height="5rem"
          max-height="12rem"
          @update:model-value="aiInstructions = $event"
        />
      </CrmAutomationField>
    </section>

    <p class="m-0 text-label-small text-n-slate-11">
      {{
        t('CRM.AUTOMATION_LIMIT_COUNT', {
          count: automations.length,
          max: MAX_AUTOMATIONS,
        })
      }}
    </p>

    <div
      v-if="!automations.length && !pickerOpen"
      class="flex flex-col items-center gap-3 p-6 text-center rounded-xl border border-dashed border-n-weak"
    >
      <Icon icon="i-lucide-zap" class="size-6 text-n-slate-10" />
      <h4 class="m-0 text-heading-3 text-n-slate-12">
        {{ t('CRM.AUTOMATION_EMPTY_TITLE') }}
      </h4>
      <p class="m-0 text-body-main text-n-slate-11">
        {{ t(TRIGGERS[kind].emptyKey) }}
      </p>
      <Button
        ref="addButton"
        type="button"
        icon="i-lucide-plus"
        :label="t('CRM.AUTOMATION_ADD')"
        @click="pickerOpen = true"
      />
    </div>

    <ol
      v-if="automations.length"
      class="flex flex-col gap-3 p-0 m-0 list-none"
      :aria-label="triggerName"
    >
      <CrmAutomationCard
        v-for="(action, index) in automations"
        :key="action.key"
        :ref="el => (cardRefs[action.key] = el)"
        :card-id="`automation-${action.key}`"
        :index="index"
        :total="automations.length"
        :type="action.type"
        :valid="isAutomationValid(action, { destinations })"
        :summary="getActionSummary(action, { t, agents, destinations })"
        :default-expanded="action.key === justAddedKey"
        @move="move(index, $event)"
        @remove="remove(index)"
      >
        <template #default="{ showErrors }">
          <CrmAutomationForm
            v-model:action="automations[index]"
            :kind="kind"
            :show-errors="showErrors"
            :autofocus="action.key === justAddedKey"
          />
        </template>
      </CrmAutomationCard>
    </ol>

    <div
      v-if="lastRemoved"
      role="status"
      class="flex items-center justify-between gap-3 px-3 py-2 rounded-lg bg-n-alpha-2 text-body-main text-n-slate-12"
    >
      {{ t('CRM.AUTOMATION_REMOVED') }}
      <Button
        type="button"
        variant="link"
        color="blue"
        size="sm"
        :label="t('CRM.AUTOMATION_UNDO')"
        @click="undo"
      />
    </div>

    <template v-if="automations.length && !pickerOpen">
      <Button
        ref="addButton"
        type="button"
        variant="faded"
        color="slate"
        icon="i-lucide-plus"
        class="self-start"
        :label="t('CRM.AUTOMATION_ADD')"
        :disabled="automations.length >= MAX_AUTOMATIONS"
        @click="pickerOpen = true"
      />
      <p
        v-if="automations.length >= MAX_AUTOMATIONS"
        class="m-0 text-label-small text-n-amber-11"
      >
        {{ t('CRM.AUTOMATION_LIMIT_REACHED', { max: MAX_AUTOMATIONS }) }}
      </p>
    </template>

    <CrmAutomationPicker
      v-if="pickerOpen"
      @select="add"
      @cancel="pickerOpen = false"
    />
  </div>
</template>
