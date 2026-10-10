<script setup>
import { computed } from 'vue';
import { useEventListener } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import Banner from 'dashboard/components-next/banner/Banner.vue';

const { t } = useI18n();
const store = useStore();
const accountId = useMapGetter('getCurrentAccountId');
const account = useFunctionGetter('accounts/getAccount', accountId);

const creditStatus = computed(() => account.value?.saas_ai_credit_status || {});
const showCreditWarning = computed(() => creditStatus.value.show_credit_warning === true);

const refreshCreditStatus = () => {
  if (!accountId.value) return;

  store.dispatch('accounts/get', {
    accountId: accountId.value,
    silent: true,
  });
};

useEventListener(window, 'focus', refreshCreditStatus);
useEventListener(window, 'saas-ai-credit-status-changed', refreshCreditStatus);
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="showCreditWarning"
    color="amber"
    role="alert"
    class="!rounded-none !justify-center flex-wrap shrink-0"
  >
    <span class="flex min-w-0 items-center gap-2 break-words text-center text-sm">
      <span class="i-lucide-triangle-alert size-4 shrink-0" />
      {{ t('GENERAL_SETTINGS.SAAS_AI_CREDIT_WARNING') }}
    </span>
  </Banner>
</template>
