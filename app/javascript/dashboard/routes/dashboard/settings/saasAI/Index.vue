<script setup>
import { computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SaasAI from 'dashboard/api/saasAI';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRoute } from 'vue-router';

const { t, tm, rt, locale } = useI18n();
const { currentAccount } = useAccount();
const route = useRoute();
const SECONDS_PER_MINUTE = 60;
const data = ref(null);
const loading = ref(true);
const loadFailed = ref(false);
const refreshing = ref(false);
const page = ref(1);
const perPage = ref(20);
const PAGE_SIZES = [10, 20, 50, 100];
const formattingLocale = computed(() => locale.value.replaceAll('_', '-'));
const formatNumber = value =>
  new Intl.NumberFormat(formattingLocale.value, {
    maximumFractionDigits: 2,
  }).format(value);
const formatDate = value =>
  new Date(value).toLocaleString(formattingLocale.value);
const statusLabel = status => rt(tm('SAAS_AI.STATES')[status]);
const hasResourceAccess = resource =>
  currentAccount.value?.features?.[
    resource === 'text_credits' ? 'text_ai' : 'voice_ai'
  ];
const wallets = computed(() =>
  (data.value?.wallets || []).filter(wallet =>
    hasResourceAccess(wallet.resource)
  )
);
const usage = computed(() =>
  (data.value?.usage || []).filter(entry => hasResourceAccess(entry.resource))
);
async function load() {
  const requestedAccount = route.params.accountId;
  const requestedPage = page.value;
  const requestedPerPage = perPage.value;
  refreshing.value = true;
  try {
    const response = await SaasAI.get({
      page: requestedPage,
      per_page: requestedPerPage,
    });
    if (
      requestedAccount !== route.params.accountId ||
      requestedPage !== page.value ||
      requestedPerPage !== perPage.value
    )
      return;
    data.value = response.data;
    loadFailed.value = false;
  } catch (error) {
    if (
      requestedAccount !== route.params.accountId ||
      requestedPage !== page.value ||
      requestedPerPage !== perPage.value
    )
      return;
    if (!data.value) loadFailed.value = true;
    const messages = tm('SAAS_AI.ERRORS');
    useAlert(rt(messages[error.response?.data?.error] || messages.generic));
  } finally {
    if (
      requestedAccount === route.params.accountId &&
      requestedPage === page.value &&
      requestedPerPage === perPage.value
    ) {
      loading.value = false;
      refreshing.value = false;
    }
  }
}
watch(
  [
    () => route.params.accountId,
    () => currentAccount.value?.features?.text_ai,
    () => currentAccount.value?.features?.voice_ai,
  ],
  ([, text, voice]) => {
    page.value = 1;
    data.value = null;
    loadFailed.value = false;
    loading.value = !!(text || voice);
    if (text || voice) load();
  },
  { immediate: true }
);
watch(page, () => {
  if (data.value) load();
});
watch(perPage, () => {
  if (page.value === 1) load();
  else page.value = 1;
});
</script>

<template>
  <SettingsLayout
    full-height
    :is-loading="loading"
    :loading-message="t('SAAS_AI.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('AI_HUB.USAGE')"
        :description="t('AI_HUB.USAGE_HELP')"
        class="shrink-0"
      />
    </template>
    <template #body>
      <p
        v-if="
          !currentAccount?.features?.text_ai &&
          !currentAccount?.features?.voice_ai
        "
        class="text-sm text-n-slate-11"
      >
        {{ t('AI_HUB.UNAVAILABLE') }}
      </p>
      <div v-else-if="loadFailed" class="flex flex-col items-start gap-4 p-6">
        <p role="alert">{{ t('SAAS_AI.LOAD_ERROR') }}</p>
        <Button :label="t('SAAS_AI.RETRY')" @click="load()" />
      </div>
      <div
        v-else-if="data"
        class="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden"
      >
        <RouterLink
          :to="{ name: 'ai_agents_settings' }"
          class="shrink-0 text-sm text-n-blue-11 hover:underline"
        >
          {{ t('AI_HUB.BACK') }}
        </RouterLink>
        <div class="grid shrink-0 grid-cols-2 gap-3">
          <section
            v-for="wallet in wallets"
            :key="wallet.resource"
            class="min-w-0 rounded-xl border border-n-weak bg-n-solid-2 p-3"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{
                wallet.resource === 'voice_seconds'
                  ? t('SAAS_AI.VOICE_BALANCE')
                  : t('SAAS_AI.TEXT_BALANCE')
              }}
            </h2>
            <p class="my-1 text-2xl font-semibold text-n-slate-12">
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
        <div class="flex shrink-0 flex-wrap items-center justify-between gap-2">
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

        <section
          v-if="currentAccount?.features?.voice_ai"
          class="flex shrink-0 flex-col gap-2"
        >
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

        <section class="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ t('SAAS_AI.USAGE_TITLE') }}
          </h2>
          <label
            class="flex shrink-0 items-center gap-3 text-body-main text-n-slate-11"
          >
            {{ t('SAAS_AI.PER_PAGE') }}
            <select
              v-model="perPage"
              class="!w-auto rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
            >
              <option v-for="size in PAGE_SIZES" :key="size" :value="size">
                {{ size }}
              </option>
            </select>
          </label>
          <p v-if="!usage.length" class="text-body-main text-n-slate-11">
            {{ t('SAAS_AI.USAGE_EMPTY') }}
          </p>
          <div
            v-else
            class="min-h-0 flex-1 overflow-auto rounded-xl border border-n-weak"
          >
            <table class="w-full text-start text-body-main">
              <thead class="sticky top-0 z-10 bg-n-solid-2">
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
                  v-for="entry in usage"
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
          <PaginationFooter
            v-if="data.usage_meta?.total_count"
            v-model:current-page="page"
            :total-items="data.usage_meta.total_count"
            :items-per-page="data.usage_meta.per_page"
            class="relative shrink-0"
          />
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
