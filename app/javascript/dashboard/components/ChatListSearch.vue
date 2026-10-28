<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { debounce } from '@chatwoot/utils';
import searchAPI from 'dashboard/api/search';
import { useAccount } from 'dashboard/composables/useAccount';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { normalizeSearchTerm } from 'dashboard/helper/searchTerm';

const MIN_LENGTH = 2;
const DEBOUNCE_MS = 300;

const { t } = useI18n();
const { accountId } = useAccount();

const query = ref('');
const results = ref([]);
const loading = ref(false);
const failed = ref(false);
const searched = ref(false);
const open = ref(false);
let requestId = 0;

const conversationUrl = conversation =>
  frontendURL(`accounts/${accountId.value}/conversations/${conversation.id}`);

const reset = () => {
  requestId += 1;
  results.value = [];
  loading.value = false;
  failed.value = false;
  searched.value = false;
};

const search = async () => {
  const term = normalizeSearchTerm(query.value);
  if (term.length < MIN_LENGTH) {
    reset();
    return;
  }

  requestId += 1;
  const current = requestId;
  loading.value = true;
  failed.value = false;
  try {
    const { data } = await searchAPI.conversations({ q: term });
    if (current !== requestId) return;
    results.value = data?.payload?.conversations ?? [];
    searched.value = true;
  } catch {
    if (current !== requestId) return;
    results.value = [];
    failed.value = true;
    searched.value = true;
  } finally {
    if (current === requestId) loading.value = false;
  }
};

const debouncedSearch = debounce(search, DEBOUNCE_MS);

const onInput = () => {
  open.value = true;
  if (normalizeSearchTerm(query.value).length < MIN_LENGTH) {
    reset();
    return;
  }
  loading.value = true;
  debouncedSearch();
};

const close = () => {
  open.value = false;
};

const clear = () => {
  query.value = '';
  reset();
};

const showPanel = computed(
  () => open.value && normalizeSearchTerm(query.value).length >= MIN_LENGTH
);

onBeforeUnmount(() => {
  requestId += 1;
});
</script>

<template>
  <OnClickOutside class="relative px-3 pb-2" @trigger="close">
    <div class="relative">
      <span
        class="absolute i-lucide-search size-3.5 top-2.5 ltr:left-3 rtl:right-3 text-n-slate-10"
        aria-hidden="true"
      />
      <input
        v-model="query"
        type="search"
        autocomplete="off"
        class="w-full h-8 py-2 text-sm border-none rounded-lg outline-none reset-base bg-n-alpha-black2 ltr:pl-9 ltr:pr-8 rtl:pr-9 rtl:pl-8 text-n-slate-12 placeholder:text-n-slate-10"
        :placeholder="t('CHAT_LIST.SEARCH.PLACEHOLDER')"
        :aria-label="t('CHAT_LIST.SEARCH.PLACEHOLDER')"
        data-test="list-search"
        @input="onInput"
        @focus="open = true"
        @keydown.esc="close"
      />
      <button
        v-if="query"
        type="button"
        class="absolute flex items-center justify-center size-5 top-1.5 ltr:right-2 rtl:left-2 text-n-slate-10 hover:text-n-slate-12"
        :aria-label="t('CHAT_LIST.SEARCH.CLEAR')"
        data-test="list-search-clear"
        @click="clear"
      >
        <span class="i-lucide-x size-3.5" aria-hidden="true" />
      </button>
    </div>

    <div
      v-if="showPanel"
      class="absolute z-30 overflow-y-auto border shadow-lg ltr:left-3 ltr:right-3 rtl:left-3 rtl:right-3 top-full max-h-80 rounded-xl bg-n-solid-1 border-n-weak"
      data-test="list-search-panel"
    >
      <p v-if="loading" class="px-3 py-3 text-sm text-n-slate-11">
        {{ t('CHAT_LIST.SEARCH.SEARCHING') }}
      </p>
      <p
        v-else-if="failed"
        role="alert"
        class="px-3 py-3 text-sm text-n-ruby-11"
      >
        {{ t('CHAT_LIST.SEARCH.ERROR') }}
      </p>
      <p
        v-else-if="searched && !results.length"
        class="px-3 py-3 text-sm text-n-slate-11"
      >
        {{ t('CHAT_LIST.SEARCH.EMPTY') }}
      </p>
      <ul v-else class="flex flex-col p-1 m-0 list-none">
        <li v-for="conversation in results" :key="conversation.id">
          <router-link
            :to="conversationUrl(conversation)"
            class="flex flex-col gap-0.5 px-3 py-2 rounded-lg hover:bg-n-alpha-2"
            data-test="list-search-result"
            @click="close"
          >
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{
                conversation.contact?.name ||
                conversation.contact?.phone_number ||
                `#${conversation.id}`
              }}
            </span>
            <span class="flex items-center gap-2 text-xs text-n-slate-11">
              <span v-if="conversation.contact?.phone_number" class="truncate">
                {{ conversation.contact.phone_number }}
              </span>
              <span class="shrink-0">#{{ conversation.id }}</span>
              <span v-if="conversation.inbox?.name" class="truncate">
                {{ conversation.inbox.name }}
              </span>
            </span>
          </router-link>
        </li>
      </ul>
    </div>
  </OnClickOutside>
</template>
