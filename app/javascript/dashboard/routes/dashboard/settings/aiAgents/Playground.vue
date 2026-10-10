<script setup>
import { nextTick, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import aiAgentsAPI from 'dashboard/api/aiAgents';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const agent = ref(null);
const runtime = ref(null);
const messages = ref([]);
const prompt = ref('');
const sessionId = ref(crypto.randomUUID());
const loading = ref(true);
const sending = ref(false);
const error = ref('');
const messagesRef = ref(null);

const scrollToBottom = () =>
  nextTick(() => {
    if (messagesRef.value) messagesRef.value.scrollTop = messagesRef.value.scrollHeight;
  });

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    const [agentResponse, sessionResponse] = await Promise.all([
      aiAgentsAPI.show(route.params.agentId),
      aiAgentsAPI.playgroundSession(route.params.agentId, sessionId.value),
    ]);
    agent.value = agentResponse.data;
    messages.value = sessionResponse.data.messages || [];
    runtime.value = sessionResponse.data.runtime;
  } catch (requestError) {
    error.value =
      requestError.response?.status === 403
        ? t('AI_PLAYGROUND.DISABLED')
        : t('AI_PLAYGROUND.LOAD_ERROR');
  } finally {
    loading.value = false;
    scrollToBottom();
  }
};

const send = async () => {
  const content = prompt.value.trim();
  if (!content || sending.value) return;

  const requestId = crypto.randomUUID();
  messages.value.push({ role: 'user', content, request_id: requestId });
  prompt.value = '';
  sending.value = true;
  error.value = '';
  scrollToBottom();
  try {
    const { data } = await aiAgentsAPI.sendPlaygroundMessage(
      route.params.agentId,
      sessionId.value,
      { request_id: requestId, message: content }
    );
    messages.value.push(data.message);
    runtime.value = data.runtime;
    scrollToBottom();
  } catch (requestError) {
    messages.value.pop();
    error.value =
      requestError.response?.data?.error === 'insufficient_balance'
        ? t('AI_PLAYGROUND.INSUFFICIENT_CREDITS')
        : t('AI_PLAYGROUND.GENERATION_ERROR');
  } finally {
    sending.value = false;
  }
};

const clearSession = async () => {
  if (sending.value) return;
  await aiAgentsAPI.clearPlaygroundSession(route.params.agentId, sessionId.value);
  sessionId.value = crypto.randomUUID();
  messages.value = [];
  error.value = '';
};

onMounted(load);
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-4 h-full">
    <header class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <RouterLink
          :to="{ name: 'ai_agents_settings', query: { type: 'text' } }"
          class="text-sm text-n-blue-11 hover:underline"
        >
          {{ t('AI_PLAYGROUND.BACK') }}
        </RouterLink>
        <h1 class="mt-2 text-xl font-semibold text-n-slate-12">
          {{ t('AI_PLAYGROUND.TITLE', { name: agent?.name || '' }) }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ agent?.active ? t('AI_AGENTS.ACTIVE') : t('AI_AGENTS.INACTIVE') }}
          <span v-if="runtime"> · {{ runtime.provider }} · {{ runtime.model }}</span>
        </p>
      </div>
      <Button
        variant="ghost"
        :label="t('AI_PLAYGROUND.CLEAR')"
        :disabled="sending || loading"
        @click="clearSession"
      />
    </header>
    <p v-if="runtime?.mode === 'platform'" class="text-sm text-n-slate-11">
      {{ t('AI_PLAYGROUND.PLATFORM_CREDITS') }}
    </p>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-9">{{ error }}</p>
    <div
      ref="messagesRef"
      class="flex flex-col flex-1 min-h-0 gap-3 p-4 overflow-y-auto rounded-lg bg-n-solid-2"
    >
      <p v-if="!loading && !messages.length" class="m-auto text-sm text-n-slate-11">
        {{ t('AI_PLAYGROUND.EMPTY') }}
      </p>
      <div
        v-for="message in messages"
        :key="`${message.request_id || message.created_at}-${message.role}`"
        class="max-w-[85%] px-3 py-2 text-sm whitespace-pre-wrap rounded-lg"
        :class="message.role === 'user' ? 'self-end bg-n-brand text-white' : 'self-start bg-n-alpha-2 text-n-slate-12'"
      >
        {{ message.content }}
      </div>
      <p v-if="sending" class="self-start text-sm text-n-slate-11">
        {{ t('AI_PLAYGROUND.RESPONDING', { name: agent?.name || '' }) }}
      </p>
    </div>
    <form class="flex items-end gap-2" @submit.prevent="send">
      <TextArea
        v-model="prompt"
        class="flex-1"
        :placeholder="t('AI_PLAYGROUND.PLACEHOLDER')"
        :max-length="8000"
        :resize="true"
        :disabled="sending || loading"
        @keydown.enter.exact.prevent="send"
      />
      <Button
        type="submit"
        :label="t('AI_PLAYGROUND.SEND')"
        :disabled="sending || loading || !prompt.trim()"
      />
    </form>
  </main>
</template>
