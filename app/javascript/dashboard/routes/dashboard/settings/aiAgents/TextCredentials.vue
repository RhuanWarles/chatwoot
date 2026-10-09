<script setup>
import { onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SaasAI from 'dashboard/api/saasAI';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t, tm, rt } = useI18n();
const providers = ['openai', 'anthropic', 'gemini'];
const data = ref(null);
const loading = ref(true);
const saving = ref(false);
const apiKey = ref('');
const form = reactive({});
const fields = ['text_mode', 'text_provider', 'text_model'];
const showError = error => {
  const messages = tm('SAAS_AI.ERRORS');
  useAlert(rt(messages[error.response?.data?.error] || messages.generic));
};
async function load() {
  loading.value = true;
  try {
    const response = await SaasAI.get();
    data.value = response.data;
    fields.forEach(field => {
      form[field] = response.data.settings[field];
    });
  } catch (error) {
    showError(error);
  } finally {
    loading.value = false;
  }
}
async function save(removeKey = false) {
  if (saving.value) return;
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
    await load();
  } catch (error) {
    showError(error);
  } finally {
    saving.value = false;
  }
}
onMounted(load);
</script>

<template>
  <details class="rounded-xl border border-n-weak p-4">
    <summary class="cursor-pointer font-medium text-n-slate-12">
      {{ t('AI_HUB.TEXT_CONNECTION') }}
    </summary>
    <p class="mt-3 text-sm text-n-slate-11">
      {{ t('AI_HUB.TEXT_CONNECTION_HELP') }}
    </p>
    <p v-if="loading" role="status">{{ t('SAAS_AI.LOADING') }}</p>
    <div v-else-if="!data" class="flex items-center gap-3 mt-3">
      <p role="alert">{{ t('SAAS_AI.LOAD_ERROR') }}</p>
      <Button :label="t('SAAS_AI.RETRY')" @click="load" />
    </div>
    <form v-else class="flex flex-col gap-4 mt-4" @submit.prevent="save()">
      <fieldset :disabled="saving" class="flex flex-col gap-4">
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
              <option value="byok" :disabled="!data.settings.encryption_ready">
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
      </fieldset>
      <Button
        type="submit"
        class="self-start"
        :label="t('SAAS_AI.SAVE')"
        :is-loading="saving"
        :disabled="saving"
      />
    </form>
  </details>
</template>
