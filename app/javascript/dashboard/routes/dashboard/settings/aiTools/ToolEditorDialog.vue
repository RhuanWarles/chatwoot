<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

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
const methodOptions = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].map(value => ({
  value,
  label: value,
}));

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

const validationError = computed(() => {
  if (!draft.value) return '';
  if (!draft.value.name.trim()) return t('AI_TOOLS.NAME_REQUIRED');
  if (!draft.value.configuration.method) return t('AI_TOOLS.METHOD_REQUIRED');
  if (!draft.value.configuration.url.trim()) return t('AI_TOOLS.URL_REQUIRED');
  try {
    const url = new URL(draft.value.configuration.url);
    if (!['http:', 'https:'].includes(url.protocol)) throw new Error('protocol');
  } catch {
    return t('AI_TOOLS.URL_INVALID');
  }
  try {
    JSON.parse(draft.value.configuration.parameters_json || '[]');
    JSON.parse(draft.value.configuration.headers_json || '{}');
    if (draft.value.secret_headers.trim()) JSON.parse(draft.value.secret_headers);
  } catch {
    return t('AI_TOOLS.JSON_INVALID');
  }
  if (
    !Number.isInteger(draft.value.configuration.timeout_seconds) ||
    draft.value.configuration.timeout_seconds < 1 ||
    draft.value.configuration.timeout_seconds > 30
  ) {
    return t('AI_TOOLS.TIMEOUT_INVALID');
  }
  return '';
});

const save = async () => {
  if (busy.value || !draft.value || validationError.value) return;
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
    const toolPayload = { ...draft.value, configuration };
    delete toolPayload.secret_headers;
    if (!draft.value.id) delete toolPayload.slug;
    if (draft.value.secret_headers.trim()) {
      toolPayload.secret_headers = JSON.parse(draft.value.secret_headers);
    }
    const payload = { ai_tool: toolPayload };
    const response = draft.value.id
      ? await aiToolsAPI.update(draft.value.id, payload)
      : await aiToolsAPI.create(payload);
    emit('saved', response.data);
    close();
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('AI_TOOLS.SAVE_ERROR');
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
    <div v-if="draft" class="flex flex-col gap-6 max-h-[65vh] overflow-y-auto p-1">
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
      <p v-if="validationError" role="alert" class="text-sm text-n-ruby-9">{{ validationError }}</p>
      <section class="flex flex-col gap-3">
        <div>
          <h3 class="text-base font-medium text-n-slate-12">{{ t('AI_TOOLS.BASIC_INFO') }}</h3>
          <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.BASIC_INFO_HELP') }}</p>
        </div>
        <Input v-model="draft.name" :label="t('AI_TOOLS.NAME')" :placeholder="t('AI_TOOLS.NAME_PLACEHOLDER')" :message="t('AI_TOOLS.NAME_HELP')" :disabled="busy" />
        <Input v-model="draft.description" :label="t('AI_TOOLS.DESCRIPTION')" :placeholder="t('AI_TOOLS.DESCRIPTION_PLACEHOLDER')" :message="t('AI_TOOLS.DESCRIPTION_HELP')" :disabled="busy" />
        <div class="flex flex-col gap-3 p-3 rounded-lg bg-n-solid-2">
          <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
            <span>{{ t('AI_TOOLS.ACTIVE') }}<span class="block text-xs text-n-slate-11">{{ t('AI_TOOLS.ACTIVE_HELP') }}</span></span>
            <Switch v-model="draft.active" :disabled="busy" />
          </label>
          <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
            <span>{{ t('AI_TOOLS.PLAYGROUND') }}<span class="block text-xs text-n-slate-11">{{ t('AI_TOOLS.PLAYGROUND_HELP') }}</span></span>
            <Switch v-model="draft.allow_in_playground" :disabled="busy" />
          </label>
        </div>
      </section>
      <section class="flex flex-col gap-3">
        <div>
          <h3 class="text-base font-medium text-n-slate-12">{{ t('AI_TOOLS.REQUEST') }}</h3>
          <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.REQUEST_HELP') }}</p>
        </div>
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('AI_TOOLS.METHOD') }}
          <ComboBox v-model="draft.configuration.method" :options="methodOptions" :disabled="busy" />
        </label>
        <Input v-model="draft.configuration.url" :label="t('AI_TOOLS.URL')" :placeholder="t('AI_TOOLS.URL_PLACEHOLDER')" :message="t('AI_TOOLS.URL_HELP')" :message-type="validationError === t('AI_TOOLS.URL_INVALID') || validationError === t('AI_TOOLS.URL_REQUIRED') ? 'error' : 'info'" :disabled="busy" />
        <Input v-model.number="draft.configuration.timeout_seconds" type="number" min="1" max="30" :label="t('AI_TOOLS.TIMEOUT')" :message="t('AI_TOOLS.TIMEOUT_HELP')" :disabled="busy" />
      </section>
      <section class="flex flex-col gap-3">
        <div>
          <h3 class="text-base font-medium text-n-slate-12">{{ t('AI_TOOLS.PARAMETERS_SECTION') }}</h3>
          <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.PARAMETERS_HELP') }}</p>
        </div>
        <textarea v-model="draft.configuration.parameters_json" rows="7" :disabled="busy" class="w-full p-3 font-mono text-sm rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" placeholder='[{"name":"order_id","type":"string","required":true}]' />
      </section>
      <section class="flex flex-col gap-3">
        <div>
          <h3 class="text-base font-medium text-n-slate-12">{{ t('AI_TOOLS.HEADERS_SECTION') }}</h3>
          <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.HEADERS_HELP') }}</p>
        </div>
        <textarea v-model="draft.configuration.headers_json" rows="4" :disabled="busy" class="w-full p-3 font-mono text-sm rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" placeholder='{"Content-Type":"application/json"}' />
        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          {{ t('AI_TOOLS.SECRETS') }}
          <span class="text-xs text-n-slate-11">{{ t('AI_TOOLS.SECRETS_HELP') }}</span>
          <textarea v-model="draft.secret_headers" rows="4" :disabled="busy" class="w-full p-3 font-mono text-sm rounded-lg bg-n-solid-2 text-n-slate-12 border border-n-weak" placeholder='{"Authorization":"Bearer ..."}' />
        </label>
      </section>
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
