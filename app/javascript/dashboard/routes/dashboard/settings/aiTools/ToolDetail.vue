<script setup>
import { computed, inject, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiToolsAPI from 'dashboard/api/aiTools';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useAlert } from 'dashboard/composables';
import CollapsibleSection from '../aiShared/CollapsibleSection.vue';
import CopyIdButton from '../aiShared/CopyIdButton.vue';
import UnsavedChangesDialog from '../aiShared/UnsavedChangesDialog.vue';
import { useUnsavedChangesGuard } from '../aiShared/useUnsavedChangesGuard';
import Logs from './Logs.vue';
import ToolTestDialog from './ToolTestDialog.vue';
import { METHOD_OPTIONS, newTool, validHttpUrl } from './form';
import { TOOLS_WORKSPACE } from './workspace';

const props = defineProps({
  tool: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const workspace = inject(TOOLS_WORKSPACE);

const leaveDialog = ref(null);
const testDialog = ref(null);
const deletion = ref(null);
const busy = ref(false);
const removed = ref(false);
const error = ref('');
const actionError = ref('');
const parameterMode = ref('visual');
const editingParameter = ref(null);
const parameterEditorOpen = ref(false);
const parametersJson = ref('[]');
const headerRows = ref([]);
const initialSecretHeaderNames = ref([]);
const initialSnapshot = ref('');
// Last version saved on the server: what "Discard" goes back to.
const savedTool = ref(props.tool);
const form = ref(newTool());
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
const responseExample = '{\n  "success": true,\n  "result": "..."\n}';
const parseJson = (value, fallback) => {
  try {
    return JSON.parse(value || fallback);
  } catch {
    return null;
  }
};

const usedBy = computed(() => workspace.linkedAgents(props.tool));
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
    !METHOD_OPTIONS.some(
      option => option.value === form.value.configuration.method
    )
  )
    return t('AI_TOOLS.METHOD_REQUIRED');
  if (!String(form.value.configuration.url || '').trim())
    return t('AI_TOOLS.URL_REQUIRED');
  if (!validHttpUrl(form.value.configuration.url))
    return t('AI_TOOLS.URL_INVALID');
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

// `active` is saved the moment it is toggled in the header, so it is not an unsaved change.
const snapshot = () => {
  const current = { ...form.value };
  delete current.active;
  return JSON.stringify({
    form: current,
    parametersJson: parametersJson.value,
    headerRows: headerRows.value,
  });
};
const isDirty = computed(
  () => !removed.value && snapshot() !== initialSnapshot.value
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

const initialize = tool => {
  const defaults = newTool();
  form.value = {
    ...defaults,
    ...tool,
    name: tool.name || '',
    description: tool.description || '',
    configuration: {
      ...defaults.configuration,
      ...(tool.configuration || {}),
    },
  };
  form.value.configuration.parameters ||= [];
  initialSecretHeaderNames.value = [
    ...(tool.configuration?.secret_header_names || []),
  ];
  syncVisualJson();
  initialSnapshot.value = snapshot();
};
initialize(props.tool);

const save = async () => {
  if (!isDirty.value || busy.value || validationError.value) return;
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
    const { data } = await aiToolsAPI.update(props.tool.id, payload);
    workspace.upsert(data);
    savedTool.value = data;
    initialize(data);
    useAlert(t('AI_TOOLS.SAVED'));
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('AI_TOOLS.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};

const discard = () => {
  error.value = '';
  initialize({ ...savedTool.value, active: form.value.active });
};

// Activating or deactivating is saved right away, like the toggle of the old list cards.
const toggleActive = async () => {
  if (busy.value) return;
  busy.value = true;
  const previous = form.value.active;
  form.value.active = !previous;
  try {
    const { data } = await aiToolsAPI.update(props.tool.id, {
      ai_tool: { active: !previous },
    });
    workspace.upsert(data);
    savedTool.value = data;
  } catch {
    form.value.active = previous;
    useAlert(t('AI_TOOLS.SAVE_ERROR'));
  } finally {
    busy.value = false;
  }
};

const remove = async () => {
  if (busy.value) return;
  busy.value = true;
  actionError.value = '';
  try {
    await aiToolsAPI.delete(props.tool.id);
    removed.value = true;
    deletion.value.close();
    await workspace.removeTool(props.tool.id);
  } catch {
    actionError.value = t('AI_TOOLS.DELETE_ERROR');
  } finally {
    busy.value = false;
  }
};

const actionMenuItems = computed(() => [
  { action: 'delete', icon: 'i-lucide-trash-2', label: t('AI_TOOLS.DELETE') },
]);
const handleMenuAction = ({ action }, hide) => {
  hide();
  if (action === 'delete') {
    actionError.value = '';
    deletion.value.open();
  }
};

useUnsavedChangesGuard(isDirty, leaveDialog);
</script>

<template>
  <div class="flex flex-col w-full">
    <header
      class="sticky top-0 z-20 flex flex-wrap items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1"
    >
      <div class="flex items-start min-w-0 gap-2">
        <Button
          class="md:hidden"
          variant="ghost"
          size="sm"
          icon="i-lucide-arrow-left"
          :aria-label="t('AI_HUB.BACK_TO_LIST')"
          @click="workspace.goToList()"
        />
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h2 class="text-heading-1 text-n-slate-12 break-words">
              {{ form.name || tool.name }}
            </h2>
            <label
              :title="t('AI_TOOLS.ACTIVE_HELP')"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <Switch
                :model-value="form.active"
                :disabled="busy"
                @update:model-value="toggleActive"
              />
              {{ form.active ? t('AI_TOOLS.ACTIVE') : t('AI_TOOLS.INACTIVE') }}
            </label>
            <CopyIdButton :id="tool.id" />
          </div>
          <p class="text-sm text-n-slate-11">
            {{ t('AI_TOOLS.ASSISTANTS_COUNT', { count: usedBy.length }) }}
          </p>
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <span v-if="isDirty" class="text-xs text-n-amber-11">{{
          t('AI_TOOLS.UNSAVED')
        }}</span>
        <Button
          variant="ghost"
          :label="t('AI_HUB.DISCARD')"
          :disabled="!isDirty || busy"
          @click="discard"
        />
        <Button
          variant="faded"
          icon="i-lucide-play"
          :label="t('AI_TOOLS.TEST')"
          :disabled="busy"
          @click="testDialog.open()"
        />
        <Button
          :label="t('AI_TOOLS.SAVE')"
          :is-loading="busy"
          :disabled="!isDirty || busy || Boolean(validationError)"
          @click="save"
        />
        <Popover align="end">
          <Button
            icon="i-lucide-ellipsis-vertical"
            variant="ghost"
            size="sm"
            :disabled="busy"
            :aria-label="t('AI_TOOLS.MORE')"
          />
          <template #content="{ hide }">
            <DropdownMenu
              class="!relative w-56 max-w-[calc(100vw-2rem)]"
              :menu-items="actionMenuItems"
              @action="handleMenuAction($event, hide)"
            />
          </template>
        </Popover>
      </div>
    </header>

    <div class="flex flex-col gap-5 p-6">
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

      <CollapsibleSection
        :title="t('AI_TOOLS.BASIC_INFO')"
        :description="t('AI_TOOLS.BASIC_INFO_HELP')"
      >
        <Input
          v-model="form.name"
          :label="t('AI_TOOLS.NAME')"
          :placeholder="t('AI_TOOLS.NAME_PLACEHOLDER')"
          :message="t('AI_TOOLS.NAME_HELP')"
        />
        <Input
          v-if="form.slug"
          :model-value="form.slug"
          disabled
          :label="t('AI_TOOLS.SLUG')"
          :message="t('AI_TOOLS.SLUG_HELP')"
        />
        <TextArea
          v-model="form.description"
          :label="t('AI_TOOLS.DESCRIPTION')"
          :placeholder="t('AI_TOOLS.DESCRIPTION_PLACEHOLDER')"
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
              >{{ t('AI_TOOLS.PLAYGROUND')
              }}<small class="block mt-1 text-xs text-n-slate-11">{{
                t('AI_TOOLS.PLAYGROUND_HELP')
              }}</small></span
            >
            <Switch v-model="form.allow_in_playground" />
          </label>
        </div>
      </CollapsibleSection>

      <CollapsibleSection
        :title="t('AI_TOOLS.PARAMETERS_SECTION')"
        :description="t('AI_TOOLS.PARAMETERS_HELP')"
      >
        <div class="flex justify-end">
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
      </CollapsibleSection>

      <CollapsibleSection
        :title="t('AI_TOOLS.REQUEST')"
        :description="t('AI_TOOLS.REQUEST_HELP')"
      >
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
      </CollapsibleSection>

      <CollapsibleSection
        :title="t('AI_TOOLS.USAGE_SECTION')"
        :description="t('AI_TOOLS.USAGE_HELP')"
      >
        <p v-if="!usedBy.length" class="text-sm text-n-slate-11">
          {{ t('AI_TOOLS.NO_ASSISTANTS') }}
        </p>
        <ul v-else class="flex flex-wrap gap-2 p-0 m-0 list-none">
          <li v-for="agent in usedBy" :key="agent.id">
            <RouterLink
              :to="{
                name: 'ai_agent_detail',
                params: { agentId: agent.id },
                query: { type: 'text' },
              }"
              class="inline-flex px-3 py-1 text-sm rounded-full bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3"
            >
              {{ agent.name }}
            </RouterLink>
          </li>
        </ul>
      </CollapsibleSection>

      <CollapsibleSection
        :title="t('AI_TOOLS.LOGS_TAB')"
        :description="t('AI_TOOLS.LOGS_SECTION_HELP')"
        :default-open="false"
        lazy
      >
        <Logs :tool-id="tool.id" />
      </CollapsibleSection>
    </div>
    <UnsavedChangesDialog ref="leaveDialog" />
    <ToolTestDialog
      ref="testDialog"
      :tool-id="tool.id"
      :agents="workspace.agents.value"
      :has-context-parameters="hasContextParameters"
      :unsaved="isDirty"
    />
    <Dialog
      ref="deletion"
      type="alert"
      :title="t('AI_TOOLS.DELETE')"
      :description="t('AI_TOOLS.DELETE_CONFIRM', { name: tool.name })"
      :is-loading="busy"
      :disable-confirm-button="busy"
      :confirm-button-label="t('AI_TOOLS.DELETE')"
      :cancel-button-label="t('AI_TOOLS.CANCEL')"
      @confirm="remove"
    >
      <p v-if="actionError" role="alert" class="text-sm text-n-ruby-9">
        {{ actionError }}
      </p>
    </Dialog>
  </div>
</template>
