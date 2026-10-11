<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  agents: { type: Array, default: () => [] },
});
const emit = defineEmits(['saved']);
const { t } = useI18n();
const dialog = ref(null);
const draft = ref(null);
const error = ref('');
const busy = ref(false);
const testAgentId = ref(null);
const testArguments = ref('{}');
const testResult = ref(null);

const defaultTool = () => ({
  name: '',
  slug: '',
  description: '',
  tool_type: 'http',
  active: false,
  allow_in_playground: false,
  secret_headers: '',
  configuration: {
    method: 'GET',
    url: '',
    timeout_seconds: 10,
    headers: {},
    query_params: {},
    body: {},
    parameters: [],
  },
});

const agentOptions = computed(() =>
  props.agents.map(agent => ({ value: agent.id, label: agent.name }))
);

const normalizeDraft = tool => {
  const source = tool ? { ...tool } : defaultTool();
  const configuration = { ...(source.configuration || {}) };
  return {
    ...source,
    secret_headers: '',
    configuration: {
      ...configuration,
      parameters_json: tool
        ? JSON.stringify(configuration.parameters || [], null, 2)
        : '',
      headers_json: tool
        ? JSON.stringify(configuration.headers || {}, null, 2)
        : '',
    },
  };
};

const open = tool => {
  draft.value = normalizeDraft(tool);
  error.value = '';
  testResult.value = null;
  testAgentId.value = agentOptions.value[0]?.value || null;
  testArguments.value = '{}';
  dialog.value.open();
};

const close = () => dialog.value?.close();

const save = async () => {
  if (busy.value || !draft.value) return;
  busy.value = true;
  error.value = '';
  try {
    const configuration = {
      ...draft.value.configuration,
      parameters: JSON.parse(draft.value.configuration.parameters_json || '[]'),
      headers: JSON.parse(draft.value.configuration.headers_json || '{}'),
    };
    delete configuration.parameters_json;
    delete configuration.headers_json;
    const payload = { ai_tool: { ...draft.value, configuration } };
    if (draft.value.secret_headers.trim()) {
      payload.ai_tool.secret_headers = JSON.parse(draft.value.secret_headers);
    }
    const response = draft.value.id
      ? await aiToolsAPI.update(draft.value.id, payload)
      : await aiToolsAPI.create(payload);
    emit('saved', response.data);
    close();
  } catch (saveError) {
    error.value = saveError.response?.data?.error || t('AI_TOOLS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const test = async () => {
  if (!draft.value?.id || !testAgentId.value || busy.value) return;
  busy.value = true;
  error.value = '';
  testResult.value = null;
  try {
    const args = JSON.parse(testArguments.value || '{}');
    const response = await aiToolsAPI.test(
      draft.value.id,
      testAgentId.value,
      args
    );
    testResult.value = response.data;
  } catch (testError) {
    error.value = testError.response?.data?.error || t('AI_TOOLS.TEST_ERROR');
  } finally {
    busy.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    overflow-y-auto
    :title="draft?.id ? t('AI_TOOLS.EDIT') : t('AI_TOOLS.NEW')"
    :is-loading="busy"
    :confirm-button-label="t('AI_TOOLS.SAVE')"
    :cancel-button-label="t('AI_TOOLS.CANCEL')"
    @confirm="save"
  >
    <div v-if="draft" class="flex flex-col gap-3 max-h-[65vh] overflow-y-auto p-1">
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
      <Input v-model="draft.name" :label="t('AI_TOOLS.NAME')" :disabled="busy" />
      <Input v-model="draft.slug" :label="t('AI_TOOLS.SLUG')" :disabled="busy" />
      <Input v-model="draft.description" :label="t('AI_TOOLS.DESCRIPTION')" :disabled="busy" />
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="draft.active" type="checkbox" :disabled="busy" />
        {{ t('AI_TOOLS.ACTIVE') }}
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="draft.allow_in_playground" type="checkbox" :disabled="busy" />
        {{ t('AI_TOOLS.PLAYGROUND') }}
      </label>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Input v-model="draft.configuration.method" :label="t('AI_TOOLS.METHOD')" :disabled="busy" />
        <Input v-model="draft.configuration.url" :label="t('AI_TOOLS.URL')" :disabled="busy" />
        <Input v-model.number="draft.configuration.timeout_seconds" type="number" min="1" max="30" :label="t('AI_TOOLS.TIMEOUT')" :disabled="busy" />
      </div>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_TOOLS.PARAMETERS') }}
        <textarea v-model="draft.configuration.parameters_json" rows="5" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" />
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_TOOLS.HEADERS') }}
        <textarea v-model="draft.configuration.headers_json" rows="3" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" />
      </label>
      <label class="flex flex-col gap-1 text-sm text-n-slate-12">
        {{ t('AI_TOOLS.SECRETS') }}
        <textarea v-model="draft.secret_headers" rows="3" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" />
      </label>
      <section v-if="draft.id" class="flex flex-col gap-3 p-3 rounded-lg bg-n-solid-2">
        <h3 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.TEST') }}</h3>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('AI_TOOLS.TEST_AGENT') }}
          <ComboBox v-model="testAgentId" :options="agentOptions" :disabled="busy || !agentOptions.length" />
        </label>
        <textarea v-model="testArguments" rows="3" :disabled="busy" class="w-full p-3 rounded-lg bg-n-solid-1 text-n-slate-12 border border-n-weak" />
        <Button variant="faded" :label="t('AI_TOOLS.RUN_TEST')" :disabled="busy || !testAgentId" @click="test" />
        <pre v-if="testResult" class="p-3 overflow-x-auto text-xs rounded-lg bg-n-solid-1 text-n-slate-11">{{ JSON.stringify(testResult, null, 2) }}</pre>
      </section>
    </div>
  </Dialog>
</template>
