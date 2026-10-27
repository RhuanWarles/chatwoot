<script setup>
import { computed, onActivated, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import api from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();
const router = useRouter();
const bases = ref([]);
const loading = ref(true);
const error = ref('');
const busy = ref(false);
const search = ref('');
const status = ref('all');
const deletion = ref(null);
const target = ref(null);

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

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    bases.value = (await api.get()).data.bases || [];
  } catch {
    error.value = t('KNOWLEDGE.ERROR');
  } finally {
    loading.value = false;
  }
};

const openEditor = base =>
  router.push(
    base
      ? { name: 'knowledge_base_edit', params: { knowledgeBaseId: base.id } }
      : { name: 'knowledge_base_new' }
  );

const askDelete = base => {
  target.value = base;
  deletion.value.open();
};

const toggle = async base => {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const response = await api.update(base.id, {
      knowledge_base: { active: !base.active },
    });
    bases.value = bases.value.map(item =>
      item.id === base.id ? response.data : item
    );
  } catch {
    error.value = t('KNOWLEDGE.ERROR');
  } finally {
    busy.value = false;
  }
};

const remove = async () => {
  if (!target.value || busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    await api.delete(target.value.id);
    bases.value = bases.value.filter(base => base.id !== target.value.id);
    deletion.value.close();
  } catch {
    error.value = t('KNOWLEDGE.ERROR');
  } finally {
    busy.value = false;
  }
};

const documentCount = count => t('KNOWLEDGE.DOCUMENTS_COUNT', { count }, count);
const agentCount = count => t('KNOWLEDGE.AGENTS_COUNT', { count }, count);
const description = base => base.description || t('KNOWLEDGE.NO_DESCRIPTION');

onMounted(load);
onActivated(() => {
  if (!loading.value) load();
});
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6 pb-8">
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div class="min-w-0">
        <p
          class="mb-1 text-xs font-medium tracking-wide uppercase text-n-slate-11"
        >
          {{ t('KNOWLEDGE.SECTION') }}
        </p>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('KNOWLEDGE.TITLE') }}
        </h1>
        <p class="max-w-2xl mt-1 text-sm text-n-slate-11">
          {{ t('KNOWLEDGE.HELP') }}
        </p>
      </div>
      <Button
        :label="t('KNOWLEDGE.CREATE')"
        icon="i-lucide-plus"
        :disabled="loading || busy"
        @click="openEditor()"
      />
    </header>

    <section
      v-if="!loading && !error && bases.length"
      class="flex flex-wrap items-end gap-3 p-4 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <Input
        v-model="search"
        class="flex-1 min-w-56"
        :label="t('KNOWLEDGE.SEARCH_BASES')"
        :placeholder="t('KNOWLEDGE.SEARCH_BASES_PLACEHOLDER')"
      />
      <label class="flex flex-col gap-1 min-w-44 text-sm text-n-slate-12">
        {{ t('KNOWLEDGE.STATUS_FILTER') }}
        <select
          v-model="status"
          class="h-10 px-3 rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12"
        >
          <option value="all">{{ t('KNOWLEDGE.ALL_STATUS') }}</option>
          <option value="active">{{ t('KNOWLEDGE.ACTIVE') }}</option>
          <option value="inactive">{{ t('KNOWLEDGE.INACTIVE') }}</option>
        </select>
      </label>
      <p class="w-full m-0 text-xs text-n-slate-11">
        {{
          t(
            'KNOWLEDGE.RESULT_COUNT',
            { count: filteredBases.length },
            filteredBases.length
          )
        }}
      </p>
    </section>

    <p v-if="loading" role="status" class="text-sm text-n-slate-11">
      {{ t('KNOWLEDGE.LOADING') }}
    </p>
    <div
      v-else-if="error"
      class="flex items-center gap-3 text-n-ruby-11"
      role="alert"
    >
      {{ error }} <Button :label="t('KNOWLEDGE.RETRY')" @click="load" />
    </div>
    <div
      v-else-if="!bases.length"
      class="flex flex-col items-start gap-4 p-8 rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <div>
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('KNOWLEDGE.EMPTY') }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('KNOWLEDGE.EMPTY_HELP') }}
        </p>
      </div>
      <Button
        :label="t('KNOWLEDGE.CREATE')"
        icon="i-lucide-plus"
        @click="openEditor()"
      />
    </div>
    <div
      v-else-if="!filteredBases.length"
      class="p-8 text-center rounded-2xl bg-n-surface-1 outline outline-1 outline-n-container shadow-sm"
    >
      <p class="text-sm text-n-slate-11">{{ t('KNOWLEDGE.EMPTY_FILTERED') }}</p>
    </div>
    <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <article
        v-for="base in filteredBases"
        :key="base.id"
        class="flex flex-col min-w-0 gap-4 p-5 rounded-2xl outline outline-1 outline-n-container bg-n-surface-1 shadow-sm transition-shadow hover:shadow-md"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h2
                class="m-0 text-base font-semibold break-words text-n-slate-12"
              >
                {{ base.name }}
              </h2>
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="
                  base.active
                    ? 'text-n-emerald-11 bg-n-emerald-2'
                    : 'text-n-slate-11 bg-n-solid-2'
                "
              >
                {{ t(base.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE') }}
              </span>
            </div>
            <p class="mt-1 text-sm break-words text-n-slate-11">
              {{ description(base) }}
            </p>
          </div>
          <details class="relative shrink-0">
            <summary
              class="flex items-center justify-center w-8 h-8 list-none rounded-lg cursor-pointer text-n-slate-11 hover:bg-n-alpha-2"
              :aria-label="t('KNOWLEDGE.MORE')"
            >
              <span class="i-lucide-ellipsis text-lg" aria-hidden="true" />
            </summary>
            <div
              class="absolute end-0 z-10 flex flex-col w-44 gap-1 p-2 mt-1 rounded-lg shadow-lg bg-n-solid-1 outline outline-1 outline-n-weak"
            >
              <Button
                variant="ghost"
                justify="start"
                :label="
                  base.active
                    ? t('KNOWLEDGE.DEACTIVATE')
                    : t('KNOWLEDGE.ACTIVATE')
                "
                :disabled="busy"
                @click="toggle(base)"
              />
              <Button
                variant="ghost"
                justify="start"
                color="ruby"
                :label="t('KNOWLEDGE.DELETE')"
                :disabled="busy"
                @click="askDelete(base)"
              />
            </div>
          </details>
        </div>
        <div class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11">
          <span>{{ documentCount(base.documents_count || 0) }}</span>
          <span aria-hidden="true">·</span>
          <span>{{ agentCount((base.agents || []).length) }}</span>
        </div>
        <div class="flex flex-wrap gap-2 pt-2 mt-auto border-t border-n-weak">
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.EDIT')"
            :disabled="busy"
            @click="openEditor(base)"
          />
        </div>
      </article>
    </div>

    <Dialog
      ref="deletion"
      type="alert"
      :title="t('KNOWLEDGE.DELETE')"
      :description="t('KNOWLEDGE.DELETE_CONFIRM', { name: target?.name })"
      :confirm-button-label="t('KNOWLEDGE.DELETE')"
      :cancel-button-label="t('KNOWLEDGE.CANCEL')"
      :disable-confirm-button="busy"
      :is-loading="busy"
      @confirm="remove"
    />
  </main>
</template>
