<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const loading = ref(true);
const busy = ref(false);
const error = ref('');
const activeTab = ref('general');
const parameterMode = ref('visual');
const editingParameter = ref(null);
const parameterEditorOpen = ref(false);
const parametersJson = ref('[]');
const headerRows = ref([]);
const initialSecretHeaderNames = ref([]);
const initialSnapshot = ref('');
const testArguments = ref('{}');
const testConversationId = ref('');
const testAgentId = ref(null);
const testResult = ref(null);
const agents = ref([]);
const form = ref({
  name: '',
  description: '',
  active: false,
  allow_in_playground: false,
  slug: '',
  secret_headers: {},
  configuration: {
    method: 'GET',
    url: '',
    timeout_seconds: 10,
    parameters: [],
    headers: {},
    query_params: {},
    body: {},
  },
});
const parameterDraft = ref({
  name: '',
  type: 'string',
  description: '',
  required: false,
  sensitive: false,
  value_source: 'ai',
  enum_values: [],
});

const SECRET_HEADER_MASK = '••••••••';
const methodOptions = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].map(value => ({
  value,
  label: value,
}));
const typeOptions = ['string', 'number', 'integer', 'boolean', 'enum'].map(
  value => ({ value, label: value })
);
const valueSourceOptions = [
  ['ai', 'AI_TOOLS.SOURCE_AI'],
  ['contact_phone', 'AI_TOOLS.SOURCE_CONTACT_PHONE'],
  ['contact_phone_e164', 'AI_TOOLS.SOURCE_CONTACT_PHONE_E164'],
  ['contact_name', 'AI_TOOLS.SOURCE_CONTACT_NAME'],
  ['contact_email', 'AI_TOOLS.SOURCE_CONTACT_EMAIL'],
  ['contact_id', 'AI_TOOLS.SOURCE_CONTACT_ID'],
  ['conversation_id', 'AI_TOOLS.SOURCE_CONVERSATION_ID'],
  ['account_id', 'AI_TOOLS.SOURCE_ACCOUNT_ID'],
  ['agent_id', 'AI_TOOLS.SOURCE_AGENT_ID'],
].map(([value, label]) => ({ value, label }));
const tabs = [
  ['general', 'AI_TOOLS.TAB_GENERAL'],
  ['parameters', 'AI_TOOLS.TAB_PARAMETERS'],
  ['request', 'AI_TOOLS.TAB_REQUEST'],
  ['test', 'AI_TOOLS.TAB_TEST'],
];
const responseExample = '{\n  "success": true,\n  "result": "..."\n}';
const parseJson = (value, fallback) => {
  try {
    return JSON.parse(value || fallback);
  } catch {
    return null;
  }
};

const isEdit = computed(() => Boolean(route.params.toolId));
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const hasContextParameters = computed(() =>
  form.value.configuration.parameters.some(
    parameter => (parameter.value_source || 'ai') !== 'ai'
  )
);
const descriptionMessage = computed(
  () => `${String(form.value.description || '').length} / 1000`
);
const validationError = computed(() => {
  if (!String(form.value.name || '').trim()) return t('AI_TOOLS.NAME_REQUIRED');
  if (!String(form.value.description || '').trim())
    return t('AI_TOOLS.DESCRIPTION_REQUIRED');
  if (
    !methodOptions.some(
      option => option.value === form.value.configuration.method
    )
  )
    return t('AI_TOOLS.METHOD_REQUIRED');
  if (!String(form.value.configuration.url || '').trim())
    return t('AI_TOOLS.URL_REQUIRED');
  try {
    if (
      !['http:', 'https:'].includes(
        new URL(form.value.configuration.url).protocol
      )
    )
      return t('AI_TOOLS.URL_INVALID');
  } catch {
    return t('AI_TOOLS.URL_INVALID');
  }
  const timeout = Number(form.value.configuration.timeout_seconds);
  if (!Number.isInteger(timeout) || timeout < 1 || timeout > 30)
    return t('AI_TOOLS.TIMEOUT_INVALID');
  const parameters = parseJson(parametersJson.value, null);
  if (parameters === null) return t('AI_TOOLS.JSON_INVALID');
  if (
    !Array.isArray(parameters) ||
    parameters.some(
      parameter =>
        !parameter ||
        !/^[a-zA-Z][a-zA-Z0-9_]*$/.test(parameter.name || '') ||
        !typeOptions.some(option => option.value === parameter.type)
    )
  )
    return t('AI_TOOLS.PARAMETERS_INVALID');
  return '';
});

const snapshot = () =>
  JSON.stringify({
    form: form.value,
    parametersJson: parametersJson.value,
    headerRows: headerRows.value,
  });
const isDirty = computed(
  () => !loading.value && snapshot() !== initialSnapshot.value
);
const sourceLabel = source =>
  valueSourceOptions.find(option => option.value === (source || 'ai'))?.label ||
  'AI_TOOLS.SOURCE_AI';

const syncVisualJson = () => {
  parametersJson.value = JSON.stringify(
    form.value.configuration.parameters || [],
    null,
    2
  );
  headerRows.value = [
    ...Object.entries(form.value.configuration.headers || {}).map(
      ([name, value]) => ({ name, value, sensitive: false, configured: true })
    ),
    ...(form.value.configuration.secret_header_names || []).map(name => ({
      name,
      value: SECRET_HEADER_MASK,
      sensitive: true,
      configured: true,
    })),
  ];
};

const syncHeadersVisual = () => {
  const rows = headerRows.value.filter(row => row.name.trim());
  form.value.configuration.headers = Object.fromEntries(
    rows
      .filter(row => !row.sensitive && row.value !== SECRET_HEADER_MASK)
      .map(row => [row.name.trim(), row.value])
  );
  const values = Object.fromEntries(
    rows
      .filter(row => row.sensitive && row.value !== SECRET_HEADER_MASK)
      .map(row => [row.name.trim(), row.value])
  );
  const names = rows
    .filter(row => row.sensitive)
    .map(row => row.name.trim())
    .sort();
  const changed =
    JSON.stringify(names) !==
      JSON.stringify([...initialSecretHeaderNames.value].sort()) ||
    Object.keys(values).length > 0;
  return { values, changed };
};

const addHeader = () =>
  headerRows.value.push({ name: '', value: '', sensitive: false });
const removeHeader = index => headerRows.value.splice(index, 1);

const syncJsonVisual = () => {
  const parsed = parseJson(parametersJson.value, null);
  if (Array.isArray(parsed)) form.value.configuration.parameters = parsed;
};

const switchParameterMode = mode => {
  if (mode === 'visual' && parameterMode.value === 'json') syncJsonVisual();
  parameterMode.value = mode;
  if (mode === 'json') syncVisualJson();
};

const openParameter = parameter => {
  parameterEditorOpen.value = true;
  editingParameter.value = parameter;
  parameterDraft.value = parameter
    ? {
        value_source: 'ai',
        ...parameter,
        enum_values: [...(parameter.enum_values || [])],
      }
    : {
        name: '',
        type: 'string',
        description: '',
        required: false,
        sensitive: false,
        value_source: 'ai',
        enum_values: [],
      };
};

const closeParameter = () => {
  parameterEditorOpen.value = false;
  editingParameter.value = null;
};

const applyParameter = () => {
  if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(parameterDraft.value.name)) return;
  const parameters = [...form.value.configuration.parameters];
  const index = editingParameter.value
    ? parameters.indexOf(editingParameter.value)
    : -1;
  if (index >= 0) parameters[index] = { ...parameterDraft.value };
  else if (!parameters.some(item => item.name === parameterDraft.value.name))
    parameters.push({ ...parameterDraft.value });
  else return;
  form.value.configuration.parameters = parameters;
  syncVisualJson();
  closeParameter();
};

const removeParameter = parameter => {
  form.value.configuration.parameters =
    form.value.configuration.parameters.filter(item => item !== parameter);
  syncVisualJson();
};

const addEnumValue = () => parameterDraft.value.enum_values.push('');
const removeEnumValue = index =>
  parameterDraft.value.enum_values.splice(index, 1);
const selectTab = tab => {
  if (tab === 'parameters' && parameterMode.value === 'json') syncJsonVisual();
  activeTab.value = tab;
};

const load = async () => {
  try {
    const [agentsResponse, toolResponse] = await Promise.all([
      aiAgentsAPI.get(),
      isEdit.value
        ? aiToolsAPI.show(route.params.toolId)
        : Promise.resolve({ data: null }),
    ]);
    agents.value = agentsResponse.data.agents || [];
    testAgentId.value = agentOptions.value[0]?.value || null;
    if (toolResponse.data) {
      const tool = toolResponse.data;
      form.value = {
        ...form.value,
        ...tool,
        name: tool.name || '',
        description: tool.description || '',
        configuration: {
          ...form.value.configuration,
          ...(tool.configuration || {}),
        },
      };
      form.value.configuration.parameters ||= [];
      initialSecretHeaderNames.value = [
        ...(tool.configuration?.secret_header_names || []),
      ];
    }
    syncVisualJson();
    initialSnapshot.value = snapshot();
  } catch {
    error.value = t('AI_TOOLS.LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const save = async () => {
  if (loading.value || busy.value || validationError.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { values: secretHeaders, changed: secretHeadersChanged } =
      syncHeadersVisual();
    syncJsonVisual();
    const configuration = { ...form.value.configuration };
    delete configuration.secret_header_names;
    const payload = {
      ai_tool: {
        name: form.value.name,
        description: form.value.description,
        active: form.value.active,
        allow_in_playground: form.value.allow_in_playground,
        configuration: {
          ...configuration,
          timeout_seconds: Number(form.value.configuration.timeout_seconds),
        },
      },
    };
    if (secretHeadersChanged) payload.ai_tool.secret_headers = secretHeaders;
    if (isEdit.value) await aiToolsAPI.update(route.params.toolId, payload);
    else await aiToolsAPI.create(payload);
    router.push({ name: 'ai_tools_settings' });
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('AI_TOOLS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const runTest = async () => {
  if (!isEdit.value || !testAgentId.value || busy.value) return;
  busy.value = true;
  error.value = '';
  testResult.value = null;
  try {
    const argumentsPayload = parseJson(testArguments.value, null);
    if (argumentsPayload === null) {
      error.value = t('AI_TOOLS.JSON_INVALID');
      return;
    }
    const response = await aiToolsAPI.test(
      route.params.toolId,
      testAgentId.value,
      argumentsPayload,
      testConversationId.value || null
    );
    testResult.value = response.data;
  } catch (testError) {
    error.value = testError.response?.data?.error || t('AI_TOOLS.TEST_ERROR');
  } finally {
    busy.value = false;
  }
};

const resultBody = result =>
  result?.body ||
  result?.response_body ||
  result?.result ||
  result?.error ||
  result;
const formatResult = result =>
  typeof result === 'string' ? result : JSON.stringify(result, null, 2);

onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full max-w-5xl gap-5 mx-auto pb-8">
    <header
      class="sticky top-0 z-20 flex flex-wrap items-center justify-between gap-4 py-3 -mx-2 px-2 border-b border-n-weak bg-n-solid-1/95 backdrop-blur-sm"
    >
      <div class="min-w-0">
        <p
          class="mb-1 text-xs font-medium tracking-wide uppercase text-n-slate-11"
        >
          {{ t('AI_TOOLS.TITLE') }}
        </p>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ isEdit ? t('AI_TOOLS.EDIT') : t('AI_TOOLS.NEW') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ isDirty ? t('AI_TOOLS.UNSAVED') : t('AI_TOOLS.PAGE_HELP') }}
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <Button
          variant="faded"
          :label="t('AI_TOOLS.CANCEL')"
          :disabled="busy"
          @click="router.push({ name: 'ai_tools_settings' })"
        />
        <Button
          :label="t('AI_TOOLS.SAVE')"
          :disabled="loading || busy || Boolean(validationError)"
          :is-loading="busy"
          @click="save"
        />
      </div>
    </header>

    <p
      v-if="error"
      role="alert"
      class="p-3 text-sm rounded-lg text-n-ruby-9 bg-n-ruby-2"
    >
      {{ error }}
    </p>
    <p
      v-if="validationError"
      role="alert"
      class="p-3 text-sm rounded-lg text-n-ruby-9 bg-n-ruby-2"
    >
      {{ validationError }}
    </p>

    <nav
      class="flex gap-1 p-1 overflow-x-auto rounded-xl bg-n-solid-2"
      :aria-label="t('AI_TOOLS.EDITOR_NAVIGATION')"
    >
      <Button
        v-for="[value, label] in tabs"
        :key="value"
        :variant="activeTab === value ? 'faded' : 'ghost'"
        :label="t(label)"
        @click="selectTab(value)"
      />
    </nav>

    <p v-if="loading" role="status" class="text-sm text-n-slate-11">
      {{ t('AI_TOOLS.LOADING') }}
    </p>

    <template v-else>
      <section
        v-if="activeTab === 'general'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t('AI_TOOLS.BASIC_INFO') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('AI_TOOLS.BASIC_INFO_HELP') }}
          </p>
        </div>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            v-model="form.name"
            :label="t('AI_TOOLS.NAME')"
            :placeholder="t('AI_TOOLS.NAME_PLACEHOLDER')"
            :message="t('AI_TOOLS.NAME_HELP')"
          />
          <div
            class="flex flex-col justify-center gap-2 p-4 rounded-lg bg-n-solid-1"
          >
            <span class="text-sm font-medium text-n-slate-12">{{
              t('AI_TOOLS.STATUS')
            }}</span>
            <span class="text-sm text-n-slate-11">{{
              form.active ? t('AI_TOOLS.ACTIVE') : t('AI_TOOLS.INACTIVE')
            }}</span>
          </div>
        </div>
        <TextArea
          v-model="form.description"
          :label="t('AI_TOOLS.DESCRIPTION')"
          :message="`${t('AI_TOOLS.DESCRIPTION_HELP')} · ${descriptionMessage}`"
          :max-length="1000"
          :show-character-count="false"
          auto-height
        />
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <label
            class="flex items-center justify-between gap-3 text-sm text-n-slate-12"
          >
            <span
              >{{ t('AI_TOOLS.ACTIVE')
              }}<small class="block mt-1 text-xs text-n-slate-11">{{
                t('AI_TOOLS.ACTIVE_HELP')
              }}</small></span
            >
            <Switch v-model="form.active" />
          </label>
          <label
            class="flex items-center justify-between gap-3 text-sm text-n-slate-12"
          >
            <span
              >{{ t('AI_TOOLS.PLAYGROUND')
              }}<small class="block mt-1 text-xs text-n-slate-11">{{
                t('AI_TOOLS.PLAYGROUND_HELP')
              }}</small></span
            >
            <Switch v-model="form.allow_in_playground" />
          </label>
        </div>
      </section>

      <section
        v-if="activeTab === 'parameters'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ t('AI_TOOLS.PARAMETERS_SECTION') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('AI_TOOLS.PARAMETERS_HELP') }}
            </p>
          </div>
          <div class="flex gap-1 p-1 rounded-lg bg-n-solid-1">
            <Button
              variant="ghost"
              :label="t('AI_TOOLS.VISUAL')"
              :disabled="parameterMode === 'visual'"
              @click="switchParameterMode('visual')"
            />
            <Button
              variant="ghost"
              :label="t('AI_TOOLS.JSON_MODE')"
              :disabled="parameterMode === 'json'"
              @click="switchParameterMode('json')"
            />
          </div>
        </div>
        <div v-if="parameterMode === 'visual'" class="flex flex-col gap-3">
          <div
            v-if="!form.configuration.parameters.length"
            class="p-5 text-sm text-center rounded-lg text-n-slate-11 bg-n-solid-1"
          >
            {{ t('AI_TOOLS.NO_PARAMETERS') }}
          </div>
          <div
            v-for="parameter in form.configuration.parameters"
            :key="parameter.name"
            class="flex flex-wrap items-center justify-between gap-3 p-4 rounded-lg bg-n-solid-1"
          >
            <div
              class="flex flex-wrap items-center gap-2 min-w-0 text-sm text-n-slate-12"
            >
              <span class="font-mono font-medium">{{ parameter.name }}</span>
              <span class="px-2 py-1 text-xs rounded bg-n-solid-2">{{
                parameter.type
              }}</span>
              <span class="text-xs text-n-slate-11">{{
                t(sourceLabel(parameter.value_source))
              }}</span>
              <span v-if="parameter.required" class="text-xs text-n-slate-11">{{
                t('AI_TOOLS.REQUIRED')
              }}</span>
            </div>
            <div class="flex gap-2">
              <Button
                variant="ghost"
                :label="t('AI_TOOLS.EDIT_PARAMETER')"
                @click="openParameter(parameter)"
              />
              <Button
                variant="ghost"
                color="ruby"
                :label="t('AI_TOOLS.DELETE')"
                @click="removeParameter(parameter)"
              />
            </div>
          </div>
          <Button
            variant="faded"
            class="self-start"
            :label="t('AI_TOOLS.ADD_PARAMETER')"
            icon="i-lucide-plus"
            @click="openParameter(null)"
          />
        </div>
        <TextArea
          v-else
          v-model="parametersJson"
          :label="t('AI_TOOLS.PARAMETERS')"
          :message="t('AI_TOOLS.JSON_SCHEMA_HELP')"
          auto-height
          min-height="12rem"
        />
        <div
          v-if="parameterEditorOpen"
          class="flex flex-col gap-4 p-5 rounded-lg outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div>
            <h3 class="font-medium text-n-slate-12">
              {{
                editingParameter
                  ? t('AI_TOOLS.EDIT_PARAMETER')
                  : t('AI_TOOLS.ADD_PARAMETER')
              }}
            </h3>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('AI_TOOLS.EDIT_PARAMETER_HELP') }}
            </p>
          </div>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <Input
              v-model="parameterDraft.name"
              :label="t('AI_TOOLS.PARAMETER_NAME')"
              placeholder="pedido_id"
            />
            <ComboBox
              v-model="parameterDraft.type"
              :label="t('AI_TOOLS.PARAMETER_TYPE')"
              :options="typeOptions"
            />
          </div>
          <ComboBox
            v-model="parameterDraft.value_source"
            :label="t('AI_TOOLS.VALUE_SOURCE')"
            :options="
              valueSourceOptions.map(option => ({
                ...option,
                label: t(option.label),
              }))
            "
          />
          <TextArea
            v-model="parameterDraft.description"
            :label="t('AI_TOOLS.PARAMETER_DESCRIPTION')"
            auto-height
          />
          <div class="flex flex-wrap gap-5">
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><Switch v-model="parameterDraft.required" />{{
                t('AI_TOOLS.PARAMETER_REQUIRED')
              }}</label
            >
            <label class="flex items-center gap-2 text-sm text-n-slate-12"
              ><Switch v-model="parameterDraft.sensitive" />{{
                t('AI_TOOLS.PARAMETER_SENSITIVE')
              }}</label
            >
          </div>
          <div
            v-if="parameterDraft.type === 'enum'"
            class="flex flex-col gap-2"
          >
            <div
              v-for="(_, index) in parameterDraft.enum_values"
              :key="index"
              class="flex items-end gap-2"
            >
              <Input
                v-model="parameterDraft.enum_values[index]"
                :label="t('AI_TOOLS.ENUM_VALUE')"
                class="flex-1"
              />
              <Button
                variant="ghost"
                color="ruby"
                :label="t('AI_TOOLS.DELETE')"
                @click="removeEnumValue(index)"
              />
            </div>
            <Button
              variant="ghost"
              class="self-start"
              :label="t('AI_TOOLS.ADD_ENUM')"
              @click="addEnumValue"
            />
          </div>
          <div class="flex flex-wrap gap-2">
            <Button
              variant="faded"
              :label="t('AI_TOOLS.CANCEL')"
              @click="closeParameter"
            />
            <Button :label="t('AI_TOOLS.APPLY')" @click="applyParameter" />
          </div>
        </div>
      </section>

      <section
        v-if="activeTab === 'request'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t('AI_TOOLS.REQUEST') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('AI_TOOLS.REQUEST_HELP') }}
          </p>
        </div>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-[10rem_1fr]">
          <ComboBox
            v-model="form.configuration.method"
            :label="t('AI_TOOLS.METHOD')"
            :options="methodOptions"
          />
          <Input
            v-model="form.configuration.url"
            :label="t('AI_TOOLS.URL')"
            :placeholder="t('AI_TOOLS.URL_PLACEHOLDER')"
            :message="t('AI_TOOLS.URL_HELP')"
          />
        </div>
        <Input
          v-model.number="form.configuration.timeout_seconds"
          type="number"
          min="1"
          max="30"
          :label="t('AI_TOOLS.TIMEOUT')"
          :message="t('AI_TOOLS.TIMEOUT_HELP')"
        />
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 class="text-sm font-medium text-n-slate-12">
                {{ t('AI_TOOLS.HEADERS_SECTION') }}
              </h3>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ t('AI_TOOLS.HEADERS_HELP') }}
              </p>
            </div>
            <Button
              variant="faded"
              :label="t('AI_TOOLS.ADD_HEADER')"
              icon="i-lucide-plus"
              @click="addHeader"
            />
          </div>
          <div v-if="!headerRows.length" class="text-sm text-n-slate-11">
            {{ t('AI_TOOLS.NO_HEADERS') }}
          </div>
          <div
            v-for="(row, index) in headerRows"
            :key="index"
            class="grid grid-cols-1 gap-2 md:grid-cols-[1fr_1fr_auto_auto] md:items-end"
          >
            <Input v-model="row.name" :label="t('AI_TOOLS.HEADER_NAME')" />
            <Input
              v-model="row.value"
              :label="t('AI_TOOLS.HEADER_VALUE')"
              :type="row.sensitive ? 'password' : 'text'"
            />
            <label class="flex items-center gap-2 pb-2 text-sm text-n-slate-12"
              ><Switch v-model="row.sensitive" />{{
                t('AI_TOOLS.SENSITIVE_HEADER')
              }}</label
            >
            <Button
              variant="ghost"
              color="ruby"
              :label="t('AI_TOOLS.DELETE')"
              @click="removeHeader(index)"
            />
          </div>
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('AI_TOOLS.SENSITIVE_HEADER_HELP') }}
          </p>
        </div>
        <div class="flex flex-col gap-3 p-4 rounded-lg bg-n-solid-1">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('AI_TOOLS.RESPONSE_CONTRACT') }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_TOOLS.RESPONSE_CONTRACT_DESCRIPTION') }}
          </p>
          <pre
            class="p-4 overflow-x-auto text-xs rounded-lg bg-n-solid-2 text-n-slate-12"
          ><code>{{ responseExample }}</code></pre>
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('AI_TOOLS.RESPONSE_CONTRACT_NOTE') }}
          </p>
        </div>
      </section>

      <section
        v-if="activeTab === 'test'"
        class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2"
      >
        <div>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t('AI_TOOLS.TEST') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('AI_TOOLS.TEST_HELP') }}
          </p>
        </div>
        <div
          v-if="!isEdit"
          class="p-4 text-sm rounded-lg text-n-slate-11 bg-n-solid-1"
        >
          {{ t('AI_TOOLS.TEST_SAVE_FIRST') }}
        </div>
        <template v-else>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <ComboBox
              v-model="testAgentId"
              :label="t('AI_TOOLS.TEST_AGENT')"
              :options="agentOptions"
              :disabled="busy || !agentOptions.length"
            />
            <Input
              v-if="hasContextParameters"
              v-model="testConversationId"
              :label="t('AI_TOOLS.TEST_CONVERSATION_ID')"
              :message="t('AI_TOOLS.TEST_CONVERSATION_HELP')"
              type="number"
            />
          </div>
          <div class="flex flex-col gap-2">
            <TextArea
              v-model="testArguments"
              :label="t('AI_TOOLS.TEST_ARGUMENTS')"
              auto-height
            />
            <p class="m-0 text-xs text-n-amber-11">
              {{ t('AI_TOOLS.REAL_REQUEST_WARNING') }}
            </p>
          </div>
          <Button
            class="self-start"
            :label="busy ? t('AI_TOOLS.TEST_LOADING') : t('AI_TOOLS.RUN_TEST')"
            :disabled="busy || !testAgentId"
            :is-loading="busy"
            @click="runTest"
          />
          <div
            v-if="testResult"
            class="flex flex-col gap-4 p-4 rounded-lg bg-n-solid-1"
          >
            <div class="flex flex-wrap items-center justify-between gap-2">
              <h3 class="font-medium text-n-slate-12">
                {{ t('AI_TOOLS.TEST_RESULT') }}
              </h3>
              <span class="text-sm text-n-slate-11">{{
                testResult.duration_ms
                  ? t('AI_TOOLS.TEST_DURATION', {
                      duration: testResult.duration_ms,
                    })
                  : ''
              }}</span>
            </div>
            <div class="grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
              <div>
                <p class="m-0 text-xs text-n-slate-11">
                  {{ t('AI_TOOLS.HTTP_CHECK') }}
                </p>
                <strong>{{ testResult.status || '—' }}</strong>
              </div>
              <div>
                <p class="m-0 text-xs text-n-slate-11">
                  {{ t('AI_TOOLS.JSON_CHECK') }}
                </p>
                <strong>{{
                  testResult.response_contract_valid
                    ? t('AI_TOOLS.VALID')
                    : t('AI_TOOLS.INVALID')
                }}</strong>
              </div>
              <div>
                <p class="m-0 text-xs text-n-slate-11">
                  {{ t('AI_TOOLS.SUCCESS_CHECK') }}
                </p>
                <strong>{{
                  testResult.success === true
                    ? t('AI_TOOLS.VALID')
                    : t('AI_TOOLS.INVALID')
                }}</strong>
              </div>
              <div>
                <p class="m-0 text-xs text-n-slate-11">
                  {{ t('AI_TOOLS.RESULT_CHECK') }}
                </p>
                <strong>{{
                  testResult.result
                    ? t('AI_TOOLS.PRESENT')
                    : t('AI_TOOLS.MISSING')
                }}</strong>
              </div>
            </div>
            <div>
              <p class="mb-1 text-xs text-n-slate-11">
                {{ t('AI_TOOLS.TEST_BODY') }}
              </p>
              <pre
                class="p-3 overflow-x-auto text-xs whitespace-pre-wrap rounded-lg bg-n-solid-2 text-n-slate-12"
                >{{ formatResult(resultBody(testResult)) }}</pre
              >
            </div>
          </div>
        </template>
      </section>
    </template>
  </main>
</template>
