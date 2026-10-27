<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t } = useI18n();
const route = useRoute();
const agent = ref(null);
const runtime = ref(null);
const availableCredits = ref(null);
const messages = ref([]);
const prompt = ref('');
const sessionId = ref(crypto.randomUUID());
const loading = ref(true);
const sending = ref(false);
const error = ref(null);
const messagesRef = ref(null);
const hasLiveTools = computed(
  () =>
    agent.value?.tools?.some(
      tool => tool.active && tool.allow_in_playground
    ) === true
);
const skippedToolsCount = computed(
  () =>
    (agent.value?.tools || []).filter(
      tool => tool.active && !tool.allow_in_playground
    ).length
);

const isNearBottom = () => {
  if (!messagesRef.value) return true;
  const { scrollHeight, scrollTop, clientHeight } = messagesRef.value;
  return scrollHeight - scrollTop - clientHeight < 48;
};

const scrollToBottom = (force = false) =>
  nextTick(() => {
    if (messagesRef.value && (force || isNearBottom()))
      messagesRef.value.scrollTop = messagesRef.value.scrollHeight;
  });

// Provider outages come back as 422 {error: code}; they are retryable, unlike configuration errors.
const PROVIDER_FAILURE_CODE = /^(provider_http_(429|5\d\d)|empty_response)$/;

const setError = requestError => {
  const status = requestError.response?.status;
  const code = requestError.response?.data?.error;
  let key = 'AI_PLAYGROUND.GENERATION_ERROR';
  if (code === 'insufficient_balance')
    key = 'AI_PLAYGROUND.INSUFFICIENT_CREDITS';
  else if (code === 'provider_timeout_or_connection_error')
    key = 'AI_PLAYGROUND.TIMEOUT_ERROR';
  else if (status === 422 && !PROVIDER_FAILURE_CODE.test(code))
    key = 'AI_PLAYGROUND.VALIDATION_ERROR';
  else if (status === 504 || requestError.code === 'ECONNABORTED')
    key = 'AI_PLAYGROUND.TIMEOUT_ERROR';
  error.value = { key, status };
};

const load = async () => {
  loading.value = true;
  error.value = null;
  try {
    const [agentResponse, sessionResponse] = await Promise.all([
      aiAgentsAPI.show(route.params.agentId),
      aiAgentsAPI.playgroundSession(route.params.agentId, sessionId.value),
    ]);
    agent.value = agentResponse.data;
    messages.value = sessionResponse.data.messages || [];
    runtime.value = sessionResponse.data.runtime;
    availableCredits.value = sessionResponse.data.available_credits;
  } catch (requestError) {
    error.value = {
      key:
        requestError.response?.status === 403
          ? 'AI_PLAYGROUND.DISABLED'
          : 'AI_PLAYGROUND.LOAD_ERROR',
    };
  } finally {
    loading.value = false;
    scrollToBottom(true);
  }
};

const send = async () => {
  const content = prompt.value.trim();
  if (!content || sending.value) return;

  const requestId = crypto.randomUUID();
  messages.value.push({ role: 'user', content, request_id: requestId });
  prompt.value = '';
  sending.value = true;
  error.value = null;
  scrollToBottom(true);
  try {
    const { data } = await aiAgentsAPI.sendPlaygroundMessage(
      route.params.agentId,
      sessionId.value,
      { request_id: requestId, message: content }
    );
    messages.value.push(data.message);
    runtime.value = data.runtime;
    availableCredits.value = data.available_credits;
    scrollToBottom();
  } catch (requestError) {
    messages.value.pop();
    setError(requestError);
  } finally {
    sending.value = false;
  }
};

const clearSession = async () => {
  if (sending.value) return;
  await aiAgentsAPI.clearPlaygroundSession(
    route.params.agentId,
    sessionId.value
  );
  sessionId.value = crypto.randomUUID();
  messages.value = [];
  error.value = null;
};

const toolCallsFor = message => message.tool_calls || message.toolCalls || [];
const toolCallName = toolCall =>
  toolCall.name || toolCall.tool_name || t('AI_PLAYGROUND.UNKNOWN_TOOL');
const toolCallStatus = toolCall =>
  toolCall.status || (toolCall.error ? 'failed' : 'completed');
const toolCallDetails = toolCall =>
  toolCall.arguments || toolCall.args || toolCall.result;

onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full min-w-0 h-full min-h-0 gap-4">
    <header
      class="sticky top-0 z-10 flex flex-wrap items-center justify-between gap-4 py-3 px-4 -mx-4 border-b border-n-container rounded-b-2xl bg-n-surface-1/95 backdrop-blur"
    >
      <div class="flex items-start min-w-0 gap-3">
        <RouterLink
          :to="{ name: 'ai_agents_settings', query: { type: 'text' } }"
          class="mt-1 text-sm text-n-blue-11 hover:underline"
        >
          {{ t('AI_PLAYGROUND.BACK') }}
        </RouterLink>
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-xl font-semibold truncate text-n-slate-12">
              {{ t('AI_PLAYGROUND.TITLE', { name: agent?.name || '' }) }}
            </h1>
            <span
              class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
              >{{
                agent?.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE')
              }}</span
            >
          </div>
          <p class="text-sm text-n-slate-11">
            <span v-if="runtime"
              >{{ runtime.provider }} · {{ runtime.model }}</span
            ><span v-else>{{ t('AI_PLAYGROUND.READY') }}</span>
          </p>
        </div>
      </div>
      <Button
        variant="faded"
        :label="t('AI_PLAYGROUND.CLEAR')"
        :disabled="sending || loading"
        @click="clearSession"
      />
    </header>

    <div
      class="flex flex-wrap items-center justify-between gap-2 text-xs text-n-slate-11"
    >
      <span v-if="runtime?.mode === 'platform'">{{
        t('AI_PLAYGROUND.PLATFORM_CREDITS', { amount: availableCredits ?? 0 })
      }}</span
      ><span v-if="runtime?.credits_per_request">{{
        t('AI_PLAYGROUND.TEST_COST', { count: runtime.credits_per_request })
      }}</span>
    </div>
    <p
      v-if="hasLiveTools"
      class="p-3 text-sm rounded-lg text-n-amber-11 bg-n-amber-2"
    >
      {{ t('AI_PLAYGROUND.LIVE_TOOLS_WARNING') }}
    </p>
    <p
      v-if="skippedToolsCount"
      class="p-3 text-sm rounded-lg text-n-slate-11 bg-n-solid-2"
    >
      {{ t('AI_PLAYGROUND.TOOLS_SKIPPED', { count: skippedToolsCount }) }}
    </p>
    <p
      v-if="error"
      role="alert"
      class="p-3 text-sm rounded-lg text-n-ruby-9 bg-n-ruby-2"
    >
      {{ t(error.key)
      }}<span v-if="error.status" class="text-xs">
        ({{ t('AI_PLAYGROUND.STATUS', { status: error.status }) }})</span
      >
    </p>

    <div
      ref="messagesRef"
      class="flex flex-col flex-1 min-h-0 gap-4 p-4 overflow-y-auto rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <p
        v-if="!loading && !messages.length"
        class="m-auto text-sm text-center text-n-slate-11"
      >
        {{ t('AI_PLAYGROUND.EMPTY') }}
      </p>
      <article
        v-for="message in messages"
        :key="`${message.request_id || message.created_at}-${message.role}`"
        class="flex flex-col gap-2 w-full max-w-[85%]"
        :class="
          message.role === 'user'
            ? 'self-end items-end'
            : 'self-start items-start'
        "
      >
        <div
          class="px-4 py-3 text-sm whitespace-pre-wrap rounded-2xl"
          :class="
            message.role === 'user'
              ? 'bg-n-brand text-white rounded-br-sm'
              : 'bg-n-alpha-2 text-n-slate-12 rounded-bl-sm'
          "
        >
          {{ message.content }}
        </div>
        <details
          v-if="
            message.role === 'assistant' &&
            (message.knowledge_sources?.length || toolCallsFor(message).length)
          "
          class="w-full text-xs text-n-slate-11"
        >
          <summary class="cursor-pointer">
            {{ t('AI_PLAYGROUND.DIAGNOSTICS') }}
          </summary>
          <div class="flex flex-col gap-2 p-3 mt-2 rounded-lg bg-n-solid-1">
            <div v-if="message.knowledge_sources?.length">
              <strong>{{
                t('KNOWLEDGE.CONTEXT_USED', {
                  count: message.knowledge_sources.length,
                })
              }}</strong>
              <p
                v-for="source in message.knowledge_sources"
                :key="source.id"
                class="mt-1 whitespace-pre-wrap"
              >
                {{ source.base }} · {{ source.document }}<br />{{
                  source.content
                }}
              </p>
            </div>
            <div
              v-for="(toolCall, index) in toolCallsFor(message)"
              :key="`${toolCall.name}-${index}`"
              class="p-2 rounded bg-n-alpha-2"
            >
              <div class="flex flex-wrap justify-between gap-2">
                <strong>{{ toolCallName(toolCall) }}</strong
                ><span
                  >{{
                    toolCallStatus(toolCall) === 'completed'
                      ? t('CONVERSATION.TOOL_EXECUTIONS.SUCCESS')
                      : t('CONVERSATION.TOOL_EXECUTIONS.FAILED')
                  }}<span v-if="toolCall.duration_ms">
                    ·
                    {{
                      t('AI_PLAYGROUND.DURATION', {
                        duration: toolCall.duration_ms,
                      })
                    }}</span
                  ></span
                >
              </div>
              <pre
                v-if="toolCallDetails(toolCall)"
                class="mt-1 overflow-x-auto whitespace-pre-wrap"
                >{{ JSON.stringify(toolCallDetails(toolCall), null, 2) }}</pre
              >
            </div>
          </div>
        </details>
      </article>
      <p v-if="sending" class="self-start text-sm text-n-slate-11">
        {{ t('AI_PLAYGROUND.RESPONDING', { name: agent?.name || '' }) }}
      </p>
    </div>

    <form
      class="flex items-end gap-2 p-3 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
      @submit.prevent="send"
    >
      <TextArea
        v-model="prompt"
        class="flex-1"
        :placeholder="t('AI_PLAYGROUND.PLACEHOLDER')"
        :max-length="8000"
        resize
        auto-height
        min-height="2.5rem"
        max-height="10rem"
        :disabled="sending || loading"
        @keydown.enter.exact.prevent="send"
      /><Button
        type="submit"
        :label="t('AI_PLAYGROUND.SEND')"
        :disabled="sending || loading || !prompt.trim()"
      />
    </form>
  </main>
</template>
