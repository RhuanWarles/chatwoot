<script setup>
import { useId } from 'vue';
import { useI18n } from 'vue-i18n';
import InfoTip from './InfoTip.vue';

// The shell of every block of the screen: title, the period it covers, and the three states a block can be in besides
// showing data: loading, failed (with a retry) and empty.
defineProps({
  title: { type: String, required: true },
  period: { type: String, default: '' },
  info: { type: String, default: '' },
  loading: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
  errorText: { type: String, default: '' },
  empty: { type: Boolean, default: false },
  emptyText: { type: String, default: '' },
});
defineEmits(['retry']);

const { t } = useI18n();
const titleId = useId();
</script>

<template>
  <section
    class="flex min-w-0 flex-col rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:p-5"
    :aria-labelledby="titleId"
    :aria-busy="loading"
  >
    <header class="flex flex-wrap items-start justify-between gap-x-3 gap-y-2">
      <div class="min-w-0">
        <h2
          :id="titleId"
          class="flex items-center gap-1.5 text-sm font-semibold text-n-slate-12"
        >
          {{ title }}
          <InfoTip v-if="info" :text="info" />
        </h2>
        <p
          v-if="period"
          class="mt-0.5 text-xs text-n-slate-11"
          data-test="card-period"
        >
          {{ period }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <slot name="actions" />
      </div>
    </header>

    <slot name="toolbar" />

    <div
      v-if="loading"
      role="status"
      :aria-label="t('AI_ANALYTICS.LOADING')"
      class="mt-4 flex animate-pulse flex-col gap-3"
      data-test="card-loading"
    >
      <div class="h-5 w-2/3 rounded bg-n-alpha-2" />
      <div class="h-24 rounded-lg bg-n-alpha-2" />
    </div>

    <div
      v-else-if="error"
      role="alert"
      class="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
      data-test="card-error"
    >
      {{ errorText || t('AI_ANALYTICS.LOAD_ERROR') }}
      <button
        type="button"
        class="min-h-11 rounded-lg px-3 font-medium underline"
        @click="$emit('retry')"
      >
        {{ t('AI_ANALYTICS.RETRY') }}
      </button>
    </div>

    <p
      v-else-if="empty"
      class="mt-4 text-sm text-n-slate-11"
      data-test="card-empty"
    >
      {{ emptyText || t('AI_ANALYTICS.NO_DATA') }}
    </p>

    <div v-else class="mt-4 flex min-h-0 flex-1 flex-col gap-4">
      <slot />
    </div>
  </section>
</template>
