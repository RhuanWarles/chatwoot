<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useIntervalFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import SaasAI from 'dashboard/api/saasAI';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t, tm, rt, locale } = useI18n();
const POLL_INTERVAL = 5000;
const SECONDS_PER_MINUTE = 60;
const MIN_CALL_SECONDS = 10;
const providers = ['openai', 'anthropic', 'gemini'];
const data = ref(null);
const loading = ref(true);
const loadFailed = ref(false);
const saving = ref(false);
const calling = ref(false);
const refreshing = ref(false);
const apiKey = ref('');
const phone = ref('');
const prompt = ref('');
const generation = ref(null);
const generating = ref(false);
const callRequest = ref(null);
const textRequest = ref(null);
const form = reactive({});
const fields = [
  'text_mode',
  'text_provider',
  'text_model',
  'inbound_enabled',
  'outbound_enabled',
  'max_call_seconds',
];

const formattingLocale = computed(() => locale.value.replaceAll('_', '-'));
const formatNumber = value =>
  new Intl.NumberFormat(formattingLocale.value, {
    maximumFractionDigits: 2,
  }).format(value);
const formatDate = value =>
  new Date(value).toLocaleString(formattingLocale.value);
const statusLabel = status => rt(tm('SAAS_AI.STATES')[status]);
const wallets = computed(() => data.value?.wallets || []);
const textReady = computed(() =>
  data.value?.settings.text_mode === 'byok'
    ? data.value?.settings.api_key_configured
    : data.value?.settings.platform_text_ready
);
const voiceReady = computed(
  () =>
    data.value?.settings.voice_ready && data.value?.settings.outbound_enabled
);
const voiceBalance = computed(
  () =>
    wallets.value.find(wallet => wallet.resource === 'voice_seconds')
      ?.available_units || 0
);

const showError = error => {
  const code = error.response?.data?.error || error.error_code || 'generic';
  const messages = tm('SAAS_AI.ERRORS');
  useAlert(rt(messages[code] || messages.generic));
};

async function load(initialize = false) {
  refreshing.value = true;
  try {
    const response = await SaasAI.get();
    data.value = response.data;
    if (initialize)
      fields.forEach(field => {
        form[field] = response.data.settings[field] ?? '';
      });
    loadFailed.value = false;
  } catch (error) {
    if (!data.value) loadFailed.value = true;
    showError(error);
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
}

async function save(removeKey = false) {
  saving.value = true;
  try {
    const settings = Object.fromEntries(
      fields.map(field => [field, form[field]])
    );
    if (apiKey.value) settings.text_api_key = apiKey.value;
    if (removeKey) {
      settings.text_api_key = null;
      settings.text_mode = 'platform';
    }
    await SaasAI.save(settings);
    apiKey.value = '';
    useAlert(t('SAAS_AI.SAVED'));
    await load(true);
  } catch (error) {
    showError(error);
  } finally {
    saving.value = false;
  }
}

async function startCall() {
  calling.value = true;
  if (callRequest.value?.customer_number !== phone.value) {
    callRequest.value = {
      customer_number: phone.value,
      request_id: crypto.randomUUID(),
    };
  }
  try {
    await SaasAI.call(callRequest.value);
    callRequest.value = null;
    phone.value = '';
    useAlert(t('SAAS_AI.CALL_QUEUED'));
    await load();
  } catch (error) {
    showError(error);
  } finally {
    calling.value = false;
  }
}

function updateGeneration(result) {
  generation.value = result;
  generating.value = ['pending', 'running'].includes(result.status);
  if (!generating.value) {
    textRequest.value = null;
    if (result.status === 'failed') showError(result);
  }
}

async function generate() {
  generating.value = true;
  if (textRequest.value?.prompt !== prompt.value) {
    textRequest.value = {
      prompt: prompt.value,
      request_id: crypto.randomUUID(),
    };
  }
  try {
    const response = await SaasAI.generate(textRequest.value);
    updateGeneration(response.data);
    await load();
  } catch (error) {
    generating.value = false;
    showError(error);
  }
}

useIntervalFn(async () => {
  if (
    data.value?.calls.some(call =>
      ['pending', 'submitting', 'queued', 'ringing', 'in-progress'].includes(
        call.status
      )
    ) &&
    !refreshing.value
  ) {
    await load();
  }
  if (
    !generation.value ||
    !['pending', 'running'].includes(generation.value.status)
  )
    return;
  try {
    const response = await SaasAI.generation(generation.value.id);
    updateGeneration(response.data);
    if (!generating.value) await load();
  } catch (error) {
    generating.value = false;
    generation.value = null;
    showError(error);
  }
}, POLL_INTERVAL);

onMounted(() => load(true));
</script>

<template>
  <SettingsLayout :is-loading="loading" :loading-message="t('SAAS_AI.LOADING')">
    <template #header>
      <BaseSettingsHeader
        :title="t('SAAS_AI.TITLE')"
        :description="t('SAAS_AI.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div v-if="loadFailed" class="flex flex-col items-start gap-4 p-6">
        <p role="alert">{{ t('SAAS_AI.LOAD_ERROR') }}</p>
        <Button :label="t('SAAS_AI.RETRY')" @click="load(true)" />
      </div>
      <div v-else-if="data" class="flex flex-col gap-6 pb-8">
        <div class="grid gap-4 md:grid-cols-2">
          <section
            v-for="wallet in wallets"
            :key="wallet.resource"
            class="rounded-xl border border-n-weak bg-n-solid-2 p-5"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{
                wallet.resource === 'voice_seconds'
                  ? t('SAAS_AI.VOICE_BALANCE')
                  : t('SAAS_AI.TEXT_BALANCE')
              }}
            </h2>
            <p class="my-3 text-3xl font-semibold text-n-slate-12">
              {{
                formatNumber(
                  wallet.available_units /
                    (wallet.resource === 'voice_seconds'
                      ? SECONDS_PER_MINUTE
                      : 1)
                )
              }}
            </p>
            <p class="text-body-main text-n-slate-11">
              {{
                t('SAAS_AI.RESERVED', {
                  amount: formatNumber(
                    wallet.reserved_units /
                      (wallet.resource === 'voice_seconds'
                        ? SECONDS_PER_MINUTE
                        : 1)
                  ),
                })
              }}
            </p>
          </section>
        </div>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-body-main text-n-slate-11">
            {{ t('SAAS_AI.BALANCE_HELP') }}
          </p>
          <Button
            outline
            :label="t('SAAS_AI.REFRESH')"
            :is-loading="refreshing"
            @click="load()"
          />
        </div>

        <form class="flex flex-col gap-6" @submit.prevent="save()">
          <section
            class="flex flex-col gap-4 rounded-xl border border-n-weak p-5"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ t('SAAS_AI.TEXT_TITLE') }}
            </h2>
            <label class="flex flex-col gap-2 text-body-main">
              {{ t('SAAS_AI.MODE') }}
              <select
                v-model="form.text_mode"
                class="mb-0 w-full rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12"
              >
                <option value="platform">{{ t('SAAS_AI.PLATFORM') }}</option>
                <option
                  value="byok"
                  :disabled="!data.settings.encryption_ready"
                >
                  {{ t('SAAS_AI.BYOK') }}
                </option>
              </select>
            </label>
            <p
              v-if="!data.settings.encryption_ready"
              class="text-body-main text-n-amber-11"
            >
              {{ t('SAAS_AI.ENCRYPTION_MISSING') }}
            </p>
            <template v-if="form.text_mode === 'byok'">
              <label class="flex flex-col gap-2 text-body-main">
                {{ t('SAAS_AI.PROVIDER') }}
                <select
                  v-model="form.text_provider"
                  class="mb-0 rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12"
                >
                  <option
                    v-for="provider in providers"
                    :key="provider"
                    :value="provider"
                  >
                    {{ provider }}
                  </option>
                </select>
              </label>
              <Input v-model="form.text_model" :label="t('SAAS_AI.MODEL')" />
              <Input
                v-model="apiKey"
                type="password"
                :label="t('SAAS_AI.API_KEY')"
                :message="
                  data.settings.api_key_configured
                    ? t('SAAS_AI.KEY_SAVED')
                    : t('SAAS_AI.KEY_HELP')
                "
              />
              <Button
                v-if="data.settings.api_key_configured"
                type="button"
                outline
                :label="t('SAAS_AI.REMOVE_KEY')"
                :disabled="saving"
                @click="save(true)"
              />
            </template>
            <template v-else>
              <p class="text-body-main text-n-slate-11">
                {{
                  t('SAAS_AI.TEXT_COST', {
                    count: data.text_credits_per_request,
                  })
                }}
              </p>
              <p
                v-if="!data.settings.platform_text_ready"
                class="text-body-main text-n-amber-11"
              >
                {{ t('SAAS_AI.TEXT_NOT_READY') }}
              </p>
            </template>
          </section>

          <section
            class="flex flex-col gap-4 rounded-xl border border-n-weak p-5"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ t('SAAS_AI.VOICE_TITLE') }}
            </h2>
            <p class="text-body-main text-n-slate-11">
              {{ t('SAAS_AI.VOICE_HELP') }}
            </p>
            <p
              v-if="!data.settings.voice_ready"
              class="text-body-main text-n-amber-11"
            >
              {{ t('SAAS_AI.VOICE_NOT_READY') }}
            </p>
            <label class="flex items-center gap-2 text-body-main">
              <input
                v-model="form.inbound_enabled"
                type="checkbox"
                :disabled="!data.settings.voice_ready"
                class="m-0"
              />
              {{ t('SAAS_AI.INBOUND') }}
            </label>
            <label class="flex items-center gap-2 text-body-main">
              <input
                v-model="form.outbound_enabled"
                type="checkbox"
                :disabled="!data.settings.voice_ready"
                class="m-0"
              />
              {{ t('SAAS_AI.OUTBOUND') }}
            </label>
            <Input
              v-model="form.max_call_seconds"
              type="number"
              min="10"
              max="3600"
              :label="t('SAAS_AI.MAX_DURATION')"
              :message="t('SAAS_AI.MAX_HELP')"
            />
          </section>
          <Button
            type="submit"
            class="self-start"
            :label="t('SAAS_AI.SAVE')"
            :is-loading="saving"
          />
        </form>

        <section
          class="flex flex-col gap-4 rounded-xl border border-n-weak p-5"
        >
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('SAAS_AI.DRAFT_TITLE') }}
          </h2>
          <p class="text-body-main text-n-slate-11">
            {{ t('SAAS_AI.DRAFT_HELP') }}
          </p>
          <label class="flex flex-col gap-2 text-body-main">
            {{ t('SAAS_AI.PROMPT') }}
            <textarea
              v-model="prompt"
              maxlength="8000"
              rows="4"
              class="mb-0 rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12"
            />
          </label>
          <Button
            class="self-start"
            :label="t('SAAS_AI.GENERATE')"
            :disabled="!textReady || !prompt.trim() || generating"
            :is-loading="generating"
            @click="generate"
          />
          <p
            v-if="generating"
            role="status"
            class="text-body-main text-n-slate-11"
          >
            {{ t('SAAS_AI.GENERATING') }}
          </p>
          <p
            v-if="generation?.response"
            class="whitespace-pre-wrap text-body-main text-n-slate-12"
          >
            {{ generation.response }}
          </p>
        </section>

        <section
          class="flex flex-col gap-4 rounded-xl border border-n-weak p-5"
        >
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('SAAS_AI.CALL') }}
          </h2>
          <Input
            v-model="phone"
            type="tel"
            :label="t('SAAS_AI.PHONE')"
            :message="t('SAAS_AI.PHONE_HELP')"
          />
          <Button
            class="self-start"
            :label="t('SAAS_AI.CALL')"
            :disabled="
              !voiceReady ||
              voiceBalance < MIN_CALL_SECONDS ||
              !phone ||
              calling
            "
            :is-loading="calling"
            @click="startCall"
          />
        </section>

        <section class="flex flex-col gap-4">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('SAAS_AI.CALLS_TITLE') }}
          </h2>
          <p v-if="!data.calls.length" class="text-body-main text-n-slate-11">
            {{ t('SAAS_AI.CALLS_EMPTY') }}
          </p>
          <article
            v-for="call in data.calls"
            :key="call.id"
            class="rounded-xl border border-n-weak p-4"
          >
            <div class="flex flex-wrap justify-between gap-2 text-body-main">
              <span>{{
                t('SAAS_AI.CALL_CUSTOMER', {
                  number: call.customer_number,
                  direction:
                    call.direction === 'inbound'
                      ? t('SAAS_AI.INBOUND_LABEL')
                      : t('SAAS_AI.OUTBOUND_LABEL'),
                })
              }}</span>
              <span>{{ statusLabel(call.status) }}</span>
            </div>
            <p class="mt-2 text-body-main text-n-slate-11">
              {{
                t('SAAS_AI.CALL_META', {
                  date: formatDate(call.created_at),
                  minutes: formatNumber(
                    call.billed_seconds / SECONDS_PER_MINUTE
                  ),
                })
              }}
            </p>
            <p
              v-if="call.summary"
              class="mt-2 whitespace-pre-wrap text-body-main text-n-slate-12"
            >
              {{ call.summary }}
            </p>
          </article>
        </section>

        <section class="flex flex-col gap-4">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('SAAS_AI.USAGE_TITLE') }}
          </h2>
          <p v-if="!data.usage.length" class="text-body-main text-n-slate-11">
            {{ t('SAAS_AI.USAGE_EMPTY') }}
          </p>
          <div v-else class="overflow-x-auto rounded-xl border border-n-weak">
            <table class="w-full text-start text-body-main">
              <thead class="bg-n-solid-2">
                <tr>
                  <th class="p-3 text-start">{{ t('SAAS_AI.DATE') }}</th>
                  <th class="p-3 text-start">{{ t('SAAS_AI.RESOURCE') }}</th>
                  <th class="p-3 text-start">{{ t('SAAS_AI.KIND') }}</th>
                  <th class="p-3 text-start">{{ t('SAAS_AI.STATUS') }}</th>
                  <th class="p-3 text-end">{{ t('SAAS_AI.AMOUNT') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="entry in data.usage"
                  :key="entry.id"
                  class="border-t border-n-weak"
                >
                  <td class="p-3">{{ formatDate(entry.created_at) }}</td>
                  <td class="p-3">
                    {{
                      entry.resource === 'voice_seconds'
                        ? t('SAAS_AI.VOICE_RESOURCE')
                        : t('SAAS_AI.TEXT_RESOURCE')
                    }}
                  </td>
                  <td class="p-3">
                    {{
                      entry.kind === 'credit'
                        ? t('SAAS_AI.CREDIT')
                        : t('SAAS_AI.CONSUMPTION')
                    }}
                  </td>
                  <td class="p-3">{{ statusLabel(entry.status) }}</td>
                  <td class="p-3 text-end">
                    {{
                      formatNumber(
                        (entry.status === 'reserved'
                          ? entry.reserved_units
                          : entry.units) /
                          (entry.resource === 'voice_seconds'
                            ? SECONDS_PER_MINUTE
                            : 1)
                      )
                    }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
