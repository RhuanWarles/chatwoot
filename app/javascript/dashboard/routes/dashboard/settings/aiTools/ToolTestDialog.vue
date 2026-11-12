<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import aiToolsAPI from 'dashboard/api/aiTools';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  toolId: {
    type: [String, Number],
    required: true,
  },
  agents: {
    type: Array,
    default: () => [],
  },
  // The tool uses Contact or Conversation values, so a conversation is needed for the test.
  hasContextParameters: {
    type: Boolean,
    default: false,
  },
  // There are edits that are not saved yet: the test runs the saved version.
  unsaved: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const dialog = ref(null);
const busy = ref(false);
const error = ref('');
const testArguments = ref('{}');
const testConversationId = ref('');
const testAgentId = ref(null);
const testResult = ref(null);

const agentOptions = computed(() =>
  props.agents.map(agent => ({ value: agent.id, label: agent.name }))
);

const parseJson = (value, fallback) => {
  try {
    return JSON.parse(value || fallback);
  } catch {
    return null;
  }
};

const open = () => {
  error.value = '';
  testResult.value = null;
  testAgentId.value ||= agentOptions.value[0]?.value || null;
  dialog.value.open();
};

const runTest = async () => {
  if (!testAgentId.value || busy.value) return;
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
      props.toolId,
      testAgentId.value,
      argumentsPayload,
      testConversationId.value || null
    );
    testResult.value = response.data;
  } catch (testError) {
    error.value =
      testError.response?.status === 404
        ? t('AI_TOOLS.TEST_NOT_FOUND')
        : testError.response?.data?.error || t('AI_TOOLS.TEST_ERROR');
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

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    overflow-y-auto
    :title="t('AI_TOOLS.TEST')"
    :is-loading="busy"
    :disable-confirm-button="busy || !testAgentId"
    :confirm-button-label="
      busy ? t('AI_TOOLS.TEST_LOADING') : t('AI_TOOLS.RUN_TEST')
    "
    :cancel-button-label="t('AI_TOOLS.CLOSE')"
    @confirm="runTest"
  >
    <div class="flex flex-col gap-4 p-1 max-h-[65vh] overflow-y-auto">
      <p class="text-sm text-n-slate-11">{{ t('AI_TOOLS.TEST_HELP') }}</p>
      <p v-if="unsaved" class="text-xs text-n-amber-11">
        {{ t('AI_TOOLS.TEST_UNSAVED_NOTE') }}
      </p>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-9">
        {{ error }}
      </p>
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
      <div
        v-if="testResult"
        class="flex flex-col gap-4 p-4 rounded-lg bg-n-solid-2"
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
              testResult.result ? t('AI_TOOLS.PRESENT') : t('AI_TOOLS.MISSING')
            }}</strong>
          </div>
        </div>
        <div>
          <p class="mb-1 text-xs text-n-slate-11">
            {{ t('AI_TOOLS.TEST_BODY') }}
          </p>
          <pre
            class="p-3 overflow-x-auto text-xs whitespace-pre-wrap rounded-lg bg-n-solid-1 text-n-slate-12"
            >{{ formatResult(resultBody(testResult)) }}</pre
          >
        </div>
      </div>
    </div>
  </Dialog>
</template>
