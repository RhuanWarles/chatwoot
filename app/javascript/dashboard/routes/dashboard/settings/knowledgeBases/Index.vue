<script setup>
import { computed, provide, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { breakpointsTailwind, useBreakpoints } from '@vueuse/core';
import api from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useAccount } from 'dashboard/composables/useAccount';
import DetailSkeleton from '../aiShared/DetailSkeleton.vue';
import DetailState from '../aiShared/DetailState.vue';
import ListSkeleton from '../aiShared/ListSkeleton.vue';
import MasterDetailLayout from '../aiShared/MasterDetailLayout.vue';
import {
  nextAfterRemoval,
  sortNewestFirst,
  useMasterDetailRedirect,
} from '../aiShared/masterDetail';
import KnowledgeBaseCreateDialog from './KnowledgeBaseCreateDialog.vue';
import { KNOWLEDGE_WORKSPACE } from './workspace';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const isMobile = useBreakpoints(breakpointsTailwind).smaller('md');

// Newest first. The detail panel reads this list.
const bases = ref([]);
const loading = ref(true);
const loaded = ref(false);
const loadError = ref('');
const paused = ref(false);
const search = ref('');
const status = ref('all');
const createDialog = ref(null);
let loadRequest = 0;

const selectedId = computed(() => route.params.knowledgeBaseId);
const selectedBase = computed(() =>
  bases.value.find(base => String(base.id) === String(selectedId.value))
);

const filteredBases = computed(() => {
  const query = search.value.trim().toLowerCase();
  return bases.value.filter(base => {
    const matchesStatus =
      status.value === 'all' ||
      (status.value === 'active' ? base.active : !base.active);
    const matchesSearch =
      !query ||
      [base.name, base.description].some(value =>
        String(value || '')
          .toLowerCase()
          .includes(query)
      );
    return matchesStatus && matchesSearch;
  });
});

const indexLocation = () => ({
  name: 'knowledge_bases_settings',
  params: { accountId: accountId.value },
});
const detailLocation = id => ({
  name: 'knowledge_base_detail',
  params: { accountId: accountId.value, knowledgeBaseId: id },
});
const isSelected = base => String(base.id) === String(selectedId.value);
const documentCount = count => t('KNOWLEDGE.DOCUMENTS_COUNT', { count }, count);
const agentCount = count => t('KNOWLEDGE.AGENTS_COUNT', { count }, count);

const load = async () => {
  loadRequest += 1;
  const request = loadRequest;
  loading.value = true;
  loaded.value = false;
  loadError.value = '';
  bases.value = [];
  try {
    const { data } = await api.get();
    if (request !== loadRequest) return;
    bases.value = sortNewestFirst(data.bases || []);
    loaded.value = true;
  } catch {
    if (request === loadRequest) loadError.value = t('KNOWLEDGE.ERROR');
  } finally {
    if (request === loadRequest) loading.value = false;
  }
};

// Keeps the left panel in sync after a save, create, toggle or upload, without reloading the list.
const upsert = base => {
  bases.value = sortNewestFirst([
    ...bases.value.filter(item => item.id !== base.id),
    base,
  ]);
};

// Opens the next base (or the previous one) in place of the deleted one; the redirect is paused so it
// does not compete with this navigation while the list changes under the current URL.
const removeBase = async id => {
  const next = nextAfterRemoval(bases.value, id);
  paused.value = true;
  try {
    bases.value = bases.value.filter(item => item.id !== id);
    await router.replace(next ? detailLocation(next.id) : indexLocation());
  } finally {
    paused.value = false;
  }
};

const goToList = () => router.push(indexLocation());

const onCreated = base => {
  upsert(base);
  router.push(detailLocation(base.id));
};

watch(accountId, () => load(), { immediate: true });

useMasterDetailRedirect({
  items: bases,
  loaded,
  selectedId,
  atIndex: computed(() => route.name === 'knowledge_bases_settings'),
  isMobile,
  paused,
  detailLocation,
  indexLocation,
});

provide(KNOWLEDGE_WORKSPACE, {
  bases,
  upsert,
  removeBase,
  goToList,
});
</script>

<template>
  <div class="flex w-full h-full min-h-0">
    <MasterDetailLayout :show-detail="Boolean(selectedId)">
      <template #master>
        <div class="flex flex-col gap-3 p-4 border-b border-n-weak">
          <h1 class="flex items-center gap-2 text-heading-3 text-n-slate-12">
            {{ t('KNOWLEDGE.TITLE') }}
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              {{ bases.length }}
            </span>
          </h1>
          <Button
            :label="t('KNOWLEDGE.CREATE')"
            icon="i-lucide-plus"
            :disabled="!loaded || Boolean(loadError)"
            @click="createDialog.open()"
          />
          <template v-if="bases.length">
            <Input
              v-model="search"
              size="sm"
              :placeholder="t('KNOWLEDGE.SEARCH_BASES_PLACEHOLDER')"
              :aria-label="t('KNOWLEDGE.SEARCH_BASES')"
            />
            <select
              v-model="status"
              :aria-label="t('KNOWLEDGE.STATUS_FILTER')"
              class="h-8 px-3 mb-0 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
            >
              <option value="all">{{ t('KNOWLEDGE.ALL_STATUS') }}</option>
              <option value="active">{{ t('KNOWLEDGE.ACTIVE') }}</option>
              <option value="inactive">{{ t('KNOWLEDGE.INACTIVE') }}</option>
            </select>
          </template>
        </div>
        <ListSkeleton v-if="loading" />
        <DetailState
          v-else-if="loadError"
          is-error
          :title="loadError"
          :action-label="t('KNOWLEDGE.RETRY')"
          @action="load"
        />
        <nav
          v-else
          class="flex flex-col flex-1 min-h-0 gap-1 p-3 overflow-y-auto"
          :aria-label="t('KNOWLEDGE.LIST_LABEL')"
        >
          <p
            v-if="bases.length && !filteredBases.length"
            class="p-3 text-sm text-n-slate-11"
          >
            {{ t('KNOWLEDGE.EMPTY_FILTERED') }}
          </p>
          <RouterLink
            v-for="base in filteredBases"
            :key="base.id"
            :to="detailLocation(base.id)"
            class="flex flex-col gap-1 p-3 transition-colors border rounded-xl"
            :class="
              isSelected(base)
                ? 'bg-n-solid-2 border-n-strong'
                : 'border-transparent hover:bg-n-alpha-1'
            "
            :aria-current="isSelected(base) ? 'page' : undefined"
          >
            <span class="flex items-center justify-between gap-2">
              <span class="font-semibold truncate text-n-slate-12">{{
                base.name
              }}</span>
              <span
                class="size-2 rounded-full shrink-0"
                :class="base.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
                role="img"
                :aria-label="
                  t(base.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE')
                "
              />
            </span>
            <span class="text-sm truncate text-n-slate-11">
              {{ documentCount(base.documents_count || 0) }}
              <span aria-hidden="true">·</span>
              {{ agentCount((base.agents || []).length) }}
            </span>
          </RouterLink>
        </nav>
      </template>

      <DetailSkeleton
        v-if="loading || (loaded && bases.length && !selectedBase)"
      />
      <DetailState
        v-else-if="loaded && !bases.length"
        :title="t('KNOWLEDGE.EMPTY')"
        :description="t('KNOWLEDGE.EMPTY_HELP')"
        :action-label="t('KNOWLEDGE.CREATE')"
        action-icon="i-lucide-plus"
        @action="createDialog.open()"
      />
      <router-view v-else-if="selectedBase" v-slot="{ Component }">
        <component :is="Component" :key="selectedId" />
      </router-view>
    </MasterDetailLayout>
    <KnowledgeBaseCreateDialog ref="createDialog" @created="onCreated" />
  </div>
</template>
