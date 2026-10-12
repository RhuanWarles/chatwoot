<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import aiToolsAPI from 'dashboard/api/aiTools';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const loading = ref(true);
const busy = ref(false);
const error = ref('');
const parameterMode = ref('visual');
const editingParameter = ref(null);
const testArguments = ref('{}');
const testConversationId = ref('');
const testResult = ref(null);
const agents = ref([]);
const form = ref({
  name: '', description: '', active: false, allow_in_playground: false, slug: '', secret_headers: {},
  configuration: { method: 'GET', url: '', timeout_seconds: 10, parameters: [], headers: {}, query_params: {}, body: {} },
});
const parameterDraft = ref({ name: '', type: 'string', description: '', required: false, sensitive: false, value_source: 'ai', enum_values: [] });
const parameterEditorOpen = ref(false);
const parametersJson = ref('[]');
const headerRows = ref([]);
const initialSecretHeaderNames = ref([]);
const SECRET_HEADER_MASK = '••••••••';
const methodOptions = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].map(value => ({ value, label: value }));
const typeOptions = ['string', 'number', 'integer', 'boolean', 'enum'].map(value => ({ value, label: value }));
const valueSourceOptions = [
  ['ai', 'AI_TOOLS.SOURCE_AI'], ['contact_phone', 'AI_TOOLS.SOURCE_CONTACT_PHONE'],
  ['contact_phone_e164', 'AI_TOOLS.SOURCE_CONTACT_PHONE_E164'], ['contact_name', 'AI_TOOLS.SOURCE_CONTACT_NAME'],
  ['contact_email', 'AI_TOOLS.SOURCE_CONTACT_EMAIL'], ['contact_id', 'AI_TOOLS.SOURCE_CONTACT_ID'],
  ['conversation_id', 'AI_TOOLS.SOURCE_CONVERSATION_ID'], ['account_id', 'AI_TOOLS.SOURCE_ACCOUNT_ID'],
  ['agent_id', 'AI_TOOLS.SOURCE_AGENT_ID'],
].map(([value, label]) => ({ value, label }));
const sourceLabel = source => valueSourceOptions.find(option => option.value === (source || 'ai'))?.label || 'AI_TOOLS.SOURCE_AI';
const hasContextParameters = computed(() => form.value.configuration.parameters.some(parameter => (parameter.value_source || 'ai') !== 'ai'));
const isEdit = computed(() => Boolean(route.params.toolId));
const agentOptions = computed(() => agents.value.map(agent => ({ value: agent.id, label: agent.name })));
const descriptionMessage = computed(() => `${String(form.value.description || '').length} / 1000`);

const syncVisualJson = () => {
  parametersJson.value = JSON.stringify(form.value.configuration.parameters || [], null, 2);
  headerRows.value = [
    ...Object.entries(form.value.configuration.headers || {}).map(([name, value]) => ({ name, value, sensitive: false, configured: true })),
    ...(form.value.configuration.secret_header_names || []).map(name => ({ name, value: SECRET_HEADER_MASK, sensitive: true, configured: true })),
  ];
};
const syncHeadersVisual = () => {
  const rows = headerRows.value.filter(row => row.name.trim());
  form.value.configuration.headers = Object.fromEntries(rows.filter(row => !row.sensitive && row.value !== SECRET_HEADER_MASK).map(row => [row.name.trim(), row.value]));
  const values = Object.fromEntries(rows.filter(row => row.sensitive && row.value !== SECRET_HEADER_MASK).map(row => [row.name.trim(), row.value]));
  const names = rows.filter(row => row.sensitive).map(row => row.name.trim()).sort();
  const changed = JSON.stringify(names) !== JSON.stringify([...initialSecretHeaderNames.value].sort()) || Object.keys(values).length > 0;
  return { values, changed };
};
const addHeader = () => headerRows.value.push({ name: '', value: '', sensitive: false });
const removeHeader = index => headerRows.value.splice(index, 1);
const syncJsonVisual = () => {
  form.value.configuration.parameters = JSON.parse(parametersJson.value || '[]');
};
const switchParameterMode = mode => {
  if (mode === 'visual' && parameterMode.value === 'json') {
    const parsed = parseJson(parametersJson.value, null);
    if (parsed) form.value.configuration.parameters = parsed;
  }
  parameterMode.value = mode;
  if (mode === 'json') syncVisualJson();
};
const openParameter = parameter => {
  parameterEditorOpen.value = true;
  editingParameter.value = parameter;
  parameterDraft.value = parameter ? { value_source: 'ai', ...parameter, enum_values: [...(parameter.enum_values || [])] } : { name: '', type: 'string', description: '', required: false, sensitive: false, value_source: 'ai', enum_values: [] };
};
const applyParameter = () => {
  if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(parameterDraft.value.name)) return;
  const parameters = [...form.value.configuration.parameters];
  const index = editingParameter.value ? parameters.indexOf(editingParameter.value) : -1;
  if (index >= 0) parameters[index] = { ...parameterDraft.value };
  else if (!parameters.some(item => item.name === parameterDraft.value.name)) parameters.push({ ...parameterDraft.value });
  else return;
  form.value.configuration.parameters = parameters;
  syncVisualJson();
  editingParameter.value = null;
  parameterEditorOpen.value = false;
};
const removeParameter = parameter => {
  form.value.configuration.parameters = form.value.configuration.parameters.filter(item => item !== parameter);
  syncVisualJson();
};
const addEnumValue = () => parameterDraft.value.enum_values.push('');
const removeEnumValue = index => parameterDraft.value.enum_values.splice(index, 1);
const parseJson = (value, fallback) => {
  try { return JSON.parse(value || fallback); } catch { return null; }
};
const validationError = computed(() => {
  if (!String(form.value.name || '').trim()) return t('AI_TOOLS.NAME_REQUIRED');
  if (!String(form.value.description || '').trim()) return t('AI_TOOLS.DESCRIPTION_REQUIRED');
  if (!methodOptions.some(option => option.value === form.value.configuration.method)) return t('AI_TOOLS.METHOD_REQUIRED');
  if (!String(form.value.configuration.url || '').trim()) return t('AI_TOOLS.URL_REQUIRED');
  try { if (!['http:', 'https:'].includes(new URL(form.value.configuration.url).protocol)) return t('AI_TOOLS.URL_INVALID'); } catch { return t('AI_TOOLS.URL_INVALID'); }
  if (!Number.isInteger(Number(form.value.configuration.timeout_seconds)) || Number(form.value.configuration.timeout_seconds) < 1 || Number(form.value.configuration.timeout_seconds) > 30) return t('AI_TOOLS.TIMEOUT_INVALID');
  const parameters = parseJson(parametersJson.value, '[]');
  if (parameters === null) return t('AI_TOOLS.JSON_INVALID');
  if (!Array.isArray(parameters) || parameters.some(parameter =>
    !parameter || !/^[a-zA-Z][a-zA-Z0-9_]*$/.test(parameter.name || '') ||
    !typeOptions.some(option => option.value === parameter.type)
  )) return t('AI_TOOLS.PARAMETERS_INVALID');
  return '';
});
const load = async () => {
  try {
    const [agentsResponse, toolResponse] = await Promise.all([aiAgentsAPI.get(), isEdit.value ? aiToolsAPI.show(route.params.toolId) : Promise.resolve({ data: null })]);
    agents.value = agentsResponse.data.agents || [];
    if (toolResponse.data) {
      const tool = toolResponse.data;
      form.value = {
        ...form.value,
        ...tool,
        name: tool.name || '',
        description: tool.description || '',
        configuration: { ...form.value.configuration, ...(tool.configuration || {}) },
      };
      initialSecretHeaderNames.value = [...(tool.configuration?.secret_header_names || [])];
    }
    syncVisualJson();
  } catch { error.value = t('AI_TOOLS.LOAD_ERROR'); }
  finally { loading.value = false; }
};
const save = async () => {
  if (loading.value || busy.value || validationError.value) return;
  busy.value = true; error.value = '';
  try {
    const { values: secretHeaders, changed: secretHeadersChanged } = syncHeadersVisual();
    syncJsonVisual();
    const configuration = { ...form.value.configuration };
    delete configuration.secret_header_names;
    const payload = { ai_tool: { name: form.value.name, description: form.value.description, active: form.value.active, allow_in_playground: form.value.allow_in_playground, configuration: { ...configuration, timeout_seconds: Number(form.value.configuration.timeout_seconds) } } };
    if (secretHeadersChanged) payload.ai_tool.secret_headers = secretHeaders;
    const response = isEdit.value ? await aiToolsAPI.update(route.params.toolId, payload) : await aiToolsAPI.create(payload);
    router.push({ name: 'ai_tools_settings' });
    return response;
  } catch (saveError) { error.value = saveError.response?.data?.message || t('AI_TOOLS.SAVE_ERROR'); }
  finally { busy.value = false; }
};
const runTest = async () => {
  if (!isEdit.value || !agentOptions.value.length) return;
  busy.value = true; error.value = '';
  try {
    const response = await aiToolsAPI.test(route.params.toolId, agentOptions.value[0].value, parseJson(testArguments.value, '{}') || {}, testConversationId.value || null);
    testResult.value = response.data;
  } catch (testError) { error.value = testError.response?.data?.error || t('AI_TOOLS.TEST_ERROR'); }
  finally { busy.value = false; }
};
onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full max-w-5xl gap-6 mx-auto pb-8">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div><h1 class="text-xl font-semibold text-n-slate-12">{{ isEdit ? t('AI_TOOLS.EDIT') : t('AI_TOOLS.NEW') }}</h1><p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.PAGE_HELP') }}</p></div>
      <div class="flex gap-2"><Button variant="faded" :label="t('AI_TOOLS.CANCEL')" :disabled="busy" @click="router.push({ name: 'ai_tools_settings' })" /><Button :label="t('AI_TOOLS.SAVE')" :disabled="loading || busy || Boolean(validationError)" @click="save" /></div>
    </header>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <p v-if="validationError" role="alert" class="text-sm text-n-ruby-9">{{ validationError }}</p>
    <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
      <div><h2 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.TOOL_SETTINGS') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.TOOL_SETTINGS_HELP') }}</p></div>
      <Input v-model="form.name" :label="t('AI_TOOLS.NAME')" :placeholder="t('AI_TOOLS.NAME_PLACEHOLDER')" :message="t('AI_TOOLS.NAME_HELP')" />
      <TextArea v-model="form.description" :label="t('AI_TOOLS.DESCRIPTION')" :message="`${t('AI_TOOLS.DESCRIPTION_HELP')} · ${descriptionMessage}`" :max-length="1000" :show-character-count="false" :auto-height="true" />
      <div class="flex flex-col gap-3 p-3 rounded-lg bg-n-solid-1"><label class="flex justify-between text-sm text-n-slate-12"><span>{{ t('AI_TOOLS.ACTIVE') }}<small class="block text-xs text-n-slate-11">{{ t('AI_TOOLS.ACTIVE_HELP') }}</small></span><Switch v-model="form.active" /></label><label class="flex justify-between text-sm text-n-slate-12"><span>{{ t('AI_TOOLS.PLAYGROUND') }}<small class="block text-xs text-n-slate-11">{{ t('AI_TOOLS.PLAYGROUND_HELP') }}</small></span><Switch v-model="form.allow_in_playground" /></label></div>
    </section>
    <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
      <div class="flex items-center justify-between"><div><h2 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.PARAMETERS_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.PARAMETERS_HELP') }}</p></div><div class="flex gap-1"><Button variant="faded" :label="t('AI_TOOLS.VISUAL')" :disabled="parameterMode === 'visual'" @click="switchParameterMode('visual')" /><Button variant="faded" :label="t('AI_TOOLS.JSON_MODE')" :disabled="parameterMode === 'json'" @click="switchParameterMode('json')" /></div></div>
      <div v-if="parameterMode === 'visual'" class="flex flex-col gap-2"><div v-for="parameter in form.configuration.parameters" :key="parameter.name" class="flex flex-wrap items-center justify-between gap-3 p-3 rounded-lg bg-n-solid-1"><span class="flex flex-wrap items-center gap-2 text-sm text-n-slate-12"><span class="font-mono">{{ parameter.name }}</span><span class="text-xs text-n-slate-11">{{ parameter.type }}</span><span class="text-xs text-n-slate-11">{{ t(sourceLabel(parameter.value_source)) }}</span><span v-if="parameter.required" class="text-xs text-n-slate-11">{{ t('AI_TOOLS.REQUIRED') }}</span></span><div class="flex gap-2"><Button variant="ghost" :label="t('AI_TOOLS.EDIT')" @click="openParameter(parameter)" /><Button variant="ghost" color="ruby" :label="t('AI_TOOLS.DELETE')" @click="removeParameter(parameter)" /></div></div><Button variant="faded" :label="t('AI_TOOLS.ADD_PARAMETER')" icon="i-lucide-plus" @click="openParameter(null)" /></div>
      <TextArea v-else v-model="parametersJson" :label="t('AI_TOOLS.PARAMETERS')" :message="t('AI_TOOLS.JSON_SCHEMA_HELP')" :auto-height="true" :min-height="'12rem'" />
      <div v-if="parameterEditorOpen" class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1"><Input v-model="parameterDraft.name" label="Name" placeholder="pedido_id" /><ComboBox v-model="parameterDraft.type" label="Type" :options="typeOptions" /><ComboBox v-model="parameterDraft.value_source" :label="t('AI_TOOLS.VALUE_SOURCE')" :options="valueSourceOptions.map(option => ({ ...option, label: t(option.label) }))" /><TextArea v-model="parameterDraft.description" label="Description" :auto-height="true" /><label class="flex justify-between text-sm text-n-slate-12">Required <Switch v-model="parameterDraft.required" /></label><label class="flex justify-between text-sm text-n-slate-12">Sensitive <Switch v-model="parameterDraft.sensitive" /></label><div v-if="parameterDraft.type === 'enum'" class="flex flex-col gap-2"><Input v-for="(_, index) in parameterDraft.enum_values" :key="index" v-model="parameterDraft.enum_values[index]" label="Enum value" /><Button variant="ghost" :label="t('AI_TOOLS.ADD_ENUM')" @click="addEnumValue" /></div><div class="flex gap-2"><Button variant="faded" :label="t('AI_TOOLS.CANCEL')" @click="parameterEditorOpen = false" /><Button :label="t('AI_TOOLS.APPLY')" @click="applyParameter" /></div></div>
    </section>
    <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2"><div><h2 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.REQUEST') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.REQUEST_HELP') }}</p></div><label class="flex flex-col gap-1 text-sm text-n-slate-12">{{ t('AI_TOOLS.METHOD') }}<ComboBox v-model="form.configuration.method" :options="methodOptions" /></label><Input v-model="form.configuration.url" :label="t('AI_TOOLS.URL')" :placeholder="t('AI_TOOLS.URL_PLACEHOLDER')" :message="t('AI_TOOLS.URL_HELP')" /><Input v-model.number="form.configuration.timeout_seconds" type="number" min="1" max="30" :label="t('AI_TOOLS.TIMEOUT')" :message="t('AI_TOOLS.TIMEOUT_HELP')" /></section>
    <section class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2"><div><h2 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.HEADERS_SECTION') }}</h2><p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.HEADERS_HELP') }}</p></div><div class="flex flex-col gap-2"><div v-for="(row, index) in headerRows" :key="index" class="flex flex-wrap items-end gap-2"><Input v-model="row.name" :label="t('AI_TOOLS.HEADER_NAME')" /><Input v-model="row.value" :label="t('AI_TOOLS.HEADER_VALUE')" :type="row.sensitive ? 'password' : 'text'" /><label class="flex items-center gap-2 pb-2 text-sm text-n-slate-12"><Switch v-model="row.sensitive" />{{ t('AI_TOOLS.SENSITIVE_HEADER') }}</label><Button variant="ghost" color="ruby" :label="t('AI_TOOLS.DELETE')" @click="removeHeader(index)" /></div><p class="text-xs text-n-slate-11">{{ t('AI_TOOLS.SENSITIVE_HEADER_HELP') }}</p><Button variant="faded" :label="t('AI_TOOLS.ADD_HEADER')" icon="i-lucide-plus" @click="addHeader" /></div></section><section v-if="isEdit" class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2"><h2 class="font-medium text-n-slate-12">{{ t('AI_TOOLS.TEST') }}</h2><Input v-if="hasContextParameters" v-model="testConversationId" :label="t('AI_TOOLS.TEST_CONVERSATION_ID')" :message="t('AI_TOOLS.TEST_CONVERSATION_HELP')" type="number" /><TextArea v-model="testArguments" :label="t('AI_TOOLS.TEST_ARGUMENTS')" :auto-height="true" /><Button :label="t('AI_TOOLS.RUN_TEST')" :disabled="busy" @click="runTest" /><pre v-if="testResult" class="p-3 overflow-x-auto text-xs rounded-lg bg-n-solid-1">{{ JSON.stringify(testResult, null, 2) }}</pre></section>
  </main>
</template>
