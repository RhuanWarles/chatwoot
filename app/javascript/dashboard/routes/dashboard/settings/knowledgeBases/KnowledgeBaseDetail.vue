<script setup>
import { computed, inject, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useAlert } from 'dashboard/composables';
import CopyIdButton from '../aiShared/CopyIdButton.vue';
import ListSkeleton from '../aiShared/ListSkeleton.vue';
import UnsavedChangesDialog from '../aiShared/UnsavedChangesDialog.vue';
import { useUnsavedChangesGuard } from '../aiShared/useUnsavedChangesGuard';
import { formFromBase } from './form';
import { KNOWLEDGE_WORKSPACE } from './workspace';

const props = defineProps({
  base: {
    type: Object,
    required: true,
  },
});

const { t, locale } = useI18n();
const workspace = inject(KNOWLEDGE_WORKSPACE);
const tabs = [
  ['documents', 'KNOWLEDGE.TAB_DOCUMENTS'],
  ['search', 'KNOWLEDGE.TAB_SEARCH'],
  ['settings', 'KNOWLEDGE.TAB_SETTINGS'],
  ['advanced', 'KNOWLEDGE.TAB_ADVANCED'],
];
// Last version saved on the server: what "Discard" goes back to.
const savedBase = ref(props.base);
const form = ref(formFromBase(props.base));
const documents = ref([]);
const pendingFiles = ref([]);
const activeTab = ref('documents');
const dragActive = ref(false);
const query = ref('');
const candidates = ref(null);
const searchError = ref('');
const searching = ref(false);
const error = ref('');
const busy = ref(false);
const loading = ref(true);
const removed = ref(false);
const progress = ref('');
const uploadResults = ref([]);
const uploadFailed = ref(false);
const fileInput = ref(null);
const leaveDialog = ref(null);
const documentDialog = ref(null);
const documentDeletion = ref(null);
const baseDeletion = ref(null);
const viewDialog = ref(null);
const extracted = ref(null);
const documentDraft = ref({ name: '', content: '', file: null });
const documentToDelete = ref(null);
let timer;

const changedChunking = computed(
  () =>
    Number(form.value.chunk_size) !== Number(form.value.initialChunkSize) ||
    Number(form.value.chunk_overlap) !== Number(form.value.initialChunkOverlap)
);
// `active` is saved the moment it is toggled in the header, so it is not an unsaved change.
const snapshot = (files = pendingFiles.value) => {
  const current = { ...form.value };
  delete current.active;
  return JSON.stringify({
    form: current,
    files: files.map(file => `${file.name}:${file.size}:${file.lastModified}`),
  });
};
const savedSnapshot = ref(snapshot());
const isDirty = computed(
  () => !removed.value && snapshot() !== savedSnapshot.value
);
const canSave = computed(() => Boolean(form.value.name.trim()));
const date = value =>
  new Date(value).toLocaleString(locale.value.replace('_', '-'));
const chunkCount = count => t('KNOWLEDGE.CHUNKS', { count }, count);
const documentCount = count => t('KNOWLEDGE.DOCUMENTS_COUNT', { count }, count);
const agentCount = count => t('KNOWLEDGE.AGENTS_COUNT', { count }, count);
const statusKey = item =>
  ['processing', 'ready', 'failed'].includes(item.status)
    ? item.status
    : 'processing';
const documentStatus = item => t(`KNOWLEDGE.STATUS.${statusKey(item)}`);
const documentType = item =>
  item.source_type === 'manual'
    ? t('KNOWLEDGE.MANUAL')
    : item.file_type || item.content_type || t('KNOWLEDGE.FILE');
const documentSize = item => {
  const size = item.file_size || item.size || item.byte_size;
  if (!size) return t('KNOWLEDGE.NOT_AVAILABLE');
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${Math.round(size / 1024)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
};
const documentError = item =>
  item.error_message || item.error || item.processing_error;
const report = failure => {
  const code = failure.response?.data?.error;
  error.value = t(
    ['invalid_file', 'document_limit'].includes(code)
      ? `KNOWLEDGE.ERRORS.${code}`
      : 'KNOWLEDGE.ERROR'
  );
};
const loadDocuments = async () => {
  documents.value = (await api.documents(props.base.id)).data.documents;
  // Keep the document count of the left panel in step with what is listed here.
  workspace.upsert({
    ...savedBase.value,
    documents_count: documents.value.length,
  });
};
const run = async action => {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    await action();
  } catch (failure) {
    report(failure);
  } finally {
    busy.value = false;
  }
};

const save = () =>
  run(async () => {
    const {
      name,
      description,
      active,
      similarity_threshold,
      retrieval_top_k,
      chunk_size,
      chunk_overlap,
    } = form.value;
    const normalizedSimilarityThreshold =
      similarity_threshold == null ? null : Number(similarity_threshold);
    if (
      normalizedSimilarityThreshold !== null &&
      !Number.isFinite(normalizedSimilarityThreshold)
    ) {
      error.value = t('KNOWLEDGE.ERROR');
      return;
    }
    const knowledge_base = {
      name,
      description: description ?? '',
      active,
      similarity_threshold: normalizedSimilarityThreshold,
      retrieval_top_k,
      chunk_size,
      chunk_overlap,
    };
    const response = await api.update(props.base.id, { knowledge_base });
    savedBase.value = { ...savedBase.value, ...response.data };
    workspace.upsert(savedBase.value);
    form.value = formFromBase(savedBase.value);
    uploadFailed.value = false;
    const items = pendingFiles.value.map(file => ({ file, status: 'pending' }));
    await Promise.all(
      items.map(async (item, index) => {
        item.status = 'uploading';
        progress.value = t('KNOWLEDGE.UPLOAD_PROGRESS', {
          current: index + 1,
          total: items.length,
        });
        try {
          const data = new FormData();
          data.append('document[name]', item.file.name.replace(/\.[^.]+$/, ''));
          data.append('document[file]', item.file);
          await api.saveDocument(props.base.id, data);
          item.status = 'success';
        } catch {
          item.status = 'failed';
        }
      })
    );
    uploadResults.value = items;
    const failed = items.filter(item => item.status === 'failed');
    pendingFiles.value = failed.map(item => item.file);
    savedSnapshot.value = snapshot([]);
    if (failed.length) {
      error.value = t('KNOWLEDGE.PARTIAL_UPLOAD', {
        failed: failed.length,
        total: items.length,
      });
      uploadFailed.value = true;
    } else {
      progress.value = '';
      uploadResults.value = [];
      useAlert(t('KNOWLEDGE.SAVED'));
    }
    if (items.length) await loadDocuments();
  });

const discard = () => {
  error.value = '';
  progress.value = '';
  uploadResults.value = [];
  uploadFailed.value = false;
  pendingFiles.value = [];
  form.value = formFromBase({
    ...savedBase.value,
    active: form.value.active,
  });
};

// Activating or deactivating is saved right away, like the toggle of the old list cards.
const toggleActive = async () => {
  if (busy.value) return;
  busy.value = true;
  const previous = form.value.active;
  form.value.active = !previous;
  try {
    const response = await api.update(props.base.id, {
      knowledge_base: { active: !previous },
    });
    savedBase.value = { ...savedBase.value, ...response.data };
    workspace.upsert(savedBase.value);
  } catch {
    form.value.active = previous;
    useAlert(t('KNOWLEDGE.ERROR'));
  } finally {
    busy.value = false;
  }
};

const removeBase = () =>
  run(async () => {
    await api.delete(props.base.id);
    removed.value = true;
    baseDeletion.value.close();
    await workspace.removeBase(props.base.id);
  });

const addFiles = files => pendingFiles.value.push(...Array.from(files));
const selectFiles = event => {
  addFiles(event.target.files);
  event.target.value = '';
};
const handleDrop = event => {
  dragActive.value = false;
  addFiles(event.dataTransfer.files);
};
const chooseFiles = () => fileInput.value?.click();
const removePending = file => {
  pendingFiles.value = pendingFiles.value.filter(item => item !== file);
};
const retryFailed = () => save();
const newDocument = () => {
  documentDraft.value = { name: '', content: '', file: null };
  documentDialog.value.open();
};
const openDocument = document =>
  run(async () => {
    const data = (await api.document(props.base.id, document.id)).data;
    documentDraft.value = {
      id: data.id,
      name: data.name,
      content: data.source_type === 'manual' ? data.content : '',
      file: null,
    };
    documentDialog.value.open();
  });
const saveDocument = () =>
  run(async () => {
    const draft = documentDraft.value;
    let payload;
    if (draft.file) {
      payload = new FormData();
      payload.append('document[name]', draft.name);
      payload.append('document[file]', draft.file);
    } else payload = { document: { name: draft.name, content: draft.content } };
    await api.saveDocument(props.base.id, payload, draft.id);
    documentDialog.value.close();
    await loadDocuments();
  });
const askDeleteDocument = document => {
  documentToDelete.value = document;
  documentDeletion.value.open();
};
const removeDocument = () =>
  run(async () => {
    await api.deleteDocument(props.base.id, documentToDelete.value.id);
    documentDeletion.value.close();
    documentToDelete.value = null;
    await loadDocuments();
  });
const reindex = document =>
  run(async () => {
    await api.reindex(props.base.id, document.id);
    await loadDocuments();
  });
const view = document =>
  run(async () => {
    extracted.value = (await api.document(props.base.id, document.id)).data;
    viewDialog.value.open();
  });
const testSearch = async () => {
  if (searching.value || !query.value.trim()) return;
  searching.value = true;
  searchError.value = '';
  candidates.value = null;
  try {
    candidates.value =
      (await api.search(props.base.id, query.value)).data.candidates || [];
  } catch {
    searchError.value = t('KNOWLEDGE.SEARCH_ERROR');
  } finally {
    searching.value = false;
  }
};

const actionMenuItems = computed(() => [
  { action: 'delete', icon: 'i-lucide-trash-2', label: t('KNOWLEDGE.DELETE') },
]);
const handleMenuAction = ({ action }, hide) => {
  hide();
  if (action === 'delete') baseDeletion.value.open();
};

useUnsavedChangesGuard(isDirty, leaveDialog);

onMounted(async () => {
  try {
    await loadDocuments();
  } catch (failure) {
    report(failure);
  } finally {
    loading.value = false;
  }
  timer = setInterval(() => {
    if (
      !document.hidden &&
      !busy.value &&
      documents.value.some(item => item.status === 'processing')
    )
      run(loadDocuments);
  }, 15000);
});
onUnmounted(() => clearInterval(timer));
</script>

<template>
  <div class="flex flex-col w-full">
    <header
      class="sticky top-0 z-20 flex flex-wrap items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1"
    >
      <div class="flex items-start min-w-0 gap-2">
        <Button
          class="md:hidden"
          variant="ghost"
          size="sm"
          icon="i-lucide-arrow-left"
          :aria-label="t('AI_HUB.BACK_TO_LIST')"
          @click="workspace.goToList()"
        />
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h2 class="text-heading-1 text-n-slate-12 break-words">
              {{ form.name || base.name }}
            </h2>
            <label
              :title="t('KNOWLEDGE.HELP')"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <Switch
                :model-value="form.active"
                :disabled="busy"
                @update:model-value="toggleActive"
              />
              {{ t(form.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE') }}
            </label>
            <CopyIdButton :id="base.id" />
          </div>
          <p class="text-sm text-n-slate-11">
            {{ documentCount(base.documents_count || 0) }}
            <span aria-hidden="true">·</span>
            {{ agentCount((base.agents || []).length) }}
          </p>
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <span v-if="isDirty" class="text-xs text-n-amber-11">{{
          t('KNOWLEDGE.UNSAVED')
        }}</span>
        <Button
          variant="ghost"
          :label="t('AI_HUB.DISCARD')"
          :disabled="!isDirty || busy"
          @click="discard"
        />
        <Button
          :label="t('KNOWLEDGE.SAVE_CHANGES')"
          :is-loading="busy"
          :disabled="!isDirty || busy || !canSave"
          @click="save"
        />
        <Popover align="end">
          <Button
            icon="i-lucide-ellipsis-vertical"
            variant="ghost"
            size="sm"
            :disabled="busy"
            :aria-label="t('KNOWLEDGE.MORE')"
          />
          <template #content="{ hide }">
            <DropdownMenu
              class="!relative w-56 max-w-[calc(100vw-2rem)]"
              :menu-items="actionMenuItems"
              @action="handleMenuAction($event, hide)"
            />
          </template>
        </Popover>
      </div>
    </header>

    <div class="flex flex-col gap-5 p-6">
      <div
        v-if="progress"
        class="p-3 text-sm rounded-lg text-n-slate-11 bg-n-solid-2"
        role="status"
      >
        {{ progress }}
      </div>
      <div
        v-if="uploadResults.length"
        class="flex flex-col gap-1 p-3 rounded-lg bg-n-solid-2"
        role="status"
      >
        <p
          v-for="item in uploadResults"
          :key="item.file.name + item.file.lastModified"
          class="text-sm"
          :class="
            item.status === 'success' ? 'text-n-teal-11' : 'text-n-ruby-11'
          "
        >
          {{ item.status === 'success' ? '✓' : '✕' }} {{ item.file.name }}
        </p>
      </div>
      <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
        {{ error }}
      </p>
      <Button
        v-if="uploadFailed && error"
        variant="faded"
        class="self-start"
        :label="t('KNOWLEDGE.RETRY_FAILED')"
        :disabled="busy"
        @click="retryFailed"
      />
      <nav
        class="flex gap-1 p-1 overflow-x-auto rounded-xl bg-n-solid-2"
        :aria-label="t('KNOWLEDGE.TITLE')"
      >
        <button
          v-for="[key, label] in tabs"
          :key="key"
          type="button"
          class="px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap"
          :class="
            activeTab === key
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-current="activeTab === key ? 'page' : undefined"
          @click="activeTab = key"
        >
          {{ t(label) }}
        </button>
      </nav>

      <section v-if="activeTab === 'documents'" class="flex flex-col gap-5">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('KNOWLEDGE.DOCUMENTS') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('KNOWLEDGE.DOCUMENTS_HELP') }}
            </p>
          </div>
          <Button
            variant="faded"
            :label="t('KNOWLEDGE.ADD_TEXT')"
            icon="i-lucide-file-pen-line"
            @click="newDocument"
          />
        </div>
        <div
          class="flex flex-col items-center gap-3 p-8 text-center border border-dashed rounded-xl border-n-weak"
          :class="dragActive ? 'bg-n-alpha-2' : 'bg-n-solid-2'"
          @dragover.prevent="dragActive = true"
          @dragleave.prevent="dragActive = false"
          @drop.prevent="handleDrop"
        >
          <span
            class="i-lucide-upload-cloud text-2xl text-n-slate-11"
            aria-hidden="true"
          />
          <p class="m-0 text-sm text-n-slate-11">
            {{ t('KNOWLEDGE.DROP_FILES') }}
          </p>
          <Button
            variant="faded"
            :label="t('KNOWLEDGE.SELECT_FILES')"
            @click="chooseFiles"
          />
          <p class="m-0 text-xs text-n-slate-10">
            {{ t('KNOWLEDGE.SUPPORTED_FORMATS') }}
          </p>
          <input
            ref="fileInput"
            type="file"
            multiple
            accept=".txt,.md,.pdf,text/plain,text/markdown,application/pdf"
            class="hidden"
            @change="selectFiles"
          />
        </div>
        <div v-if="pendingFiles.length" class="flex flex-col gap-2">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ t('KNOWLEDGE.PENDING_UPLOADS') }}
          </h3>
          <div
            v-for="file in pendingFiles"
            :key="file.name + file.lastModified"
            class="flex items-center justify-between gap-3 p-3 rounded-lg bg-n-solid-2"
          >
            <span class="text-sm truncate text-n-slate-12">{{ file.name }}</span
            ><Button
              variant="ghost"
              color="ruby"
              :label="t('KNOWLEDGE.REMOVE_PENDING')"
              @click="removePending(file)"
            />
          </div>
        </div>
        <ListSkeleton v-if="loading" />
        <div
          v-else-if="!documents.length"
          class="p-8 text-center rounded-xl bg-n-solid-2"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('KNOWLEDGE.NO_DOCUMENTS') }}
          </p>
        </div>
        <div v-else class="flex flex-col gap-3">
          <article
            v-for="item in documents"
            :key="item.id"
            class="flex flex-wrap items-start justify-between gap-4 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
          >
            <div class="min-w-0">
              <h3 class="font-medium break-words text-n-slate-12">
                {{ item.name }}
              </h3>
              <div
                class="flex flex-wrap gap-x-2 gap-y-1 mt-1 text-xs text-n-slate-11"
              >
                <span>{{ documentType(item) }}</span
                ><span aria-hidden="true">·</span
                ><span>{{ documentSize(item) }}</span
                ><span aria-hidden="true">·</span
                ><span>{{ date(item.updated_at) }}</span>
              </div>
              <div class="flex flex-wrap gap-2 mt-2 text-xs">
                <span
                  class="px-2 py-0.5 rounded-full"
                  :class="
                    statusKey(item) === 'failed'
                      ? 'text-n-ruby-11 bg-n-ruby-2'
                      : statusKey(item) === 'ready'
                        ? 'text-n-emerald-11 bg-n-emerald-2'
                        : 'text-n-amber-11 bg-n-amber-2'
                  "
                  >{{ documentStatus(item) }}</span
                ><span class="text-n-slate-11">{{
                  chunkCount(item.chunks_count || 0)
                }}</span>
              </div>
              <p v-if="documentError(item)" class="mt-2 text-sm text-n-ruby-11">
                {{ documentError(item) }}
              </p>
            </div>
            <div class="flex flex-wrap gap-2 ms-auto">
              <Button
                variant="ghost"
                :label="t('KNOWLEDGE.VIEW')"
                @click="view(item)"
              /><Button
                v-if="item.source_type === 'manual'"
                variant="ghost"
                :label="t('KNOWLEDGE.EDIT')"
                @click="openDocument(item)"
              /><Button
                v-if="statusKey(item) === 'failed'"
                variant="ghost"
                :label="t('KNOWLEDGE.RETRY_DOCUMENT')"
                @click="reindex(item)"
              /><Button
                variant="ghost"
                color="ruby"
                :label="t('KNOWLEDGE.DELETE')"
                @click="askDeleteDocument(item)"
              />
            </div>
          </article>
        </div>
      </section>
      <section v-else-if="activeTab === 'search'" class="flex flex-col gap-5">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('KNOWLEDGE.SEARCH_TEST') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('KNOWLEDGE.SEARCH_HELP') }}
          </p>
        </div>
        <form class="flex flex-wrap gap-2" @submit.prevent="testSearch">
          <Input
            v-model="query"
            class="flex-1 min-w-60"
            :placeholder="t('KNOWLEDGE.SEARCH_QUESTION')"
          /><Button
            type="submit"
            :label="t('KNOWLEDGE.SEARCH')"
            :disabled="searching || !query.trim()"
            :is-loading="searching"
          />
        </form>
        <p v-if="searchError" role="alert" class="text-sm text-n-ruby-11">
          {{ searchError }}
        </p>
        <p
          v-else-if="candidates && !candidates.length"
          class="p-6 text-sm text-center rounded-xl text-n-slate-11 bg-n-solid-2"
        >
          {{ t('KNOWLEDGE.NO_RESULTS') }}
        </p>
        <div v-else-if="candidates" class="flex flex-col gap-3">
          <article
            v-for="(candidate, index) in candidates"
            :key="candidate.id || index"
            class="p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
          >
            <div
              class="flex flex-wrap justify-between gap-2 text-xs text-n-slate-11"
            >
              <span
                >{{
                  t('KNOWLEDGE.RESULT_RANK', {
                    rank: candidate.rank || index + 1,
                  })
                }}
                · {{ candidate.document || t('KNOWLEDGE.NOT_AVAILABLE') }}</span
              ><span>{{
                t('KNOWLEDGE.RESULT_SCORE', { score: candidate.score })
              }}</span>
            </div>
            <p
              class="mt-2 text-sm whitespace-pre-wrap break-words text-n-slate-12"
            >
              {{ candidate.content }}
            </p>
            <span
              class="inline-flex mt-3 px-2 py-0.5 text-xs rounded-full"
              :class="
                candidate.accepted
                  ? 'text-n-emerald-11 bg-n-emerald-2'
                  : 'text-n-slate-11 bg-n-solid-2'
              "
              >{{
                t(
                  candidate.accepted
                    ? 'KNOWLEDGE.ACCEPTED'
                    : 'KNOWLEDGE.REJECTED'
                )
              }}</span
            >
          </article>
        </div>
      </section>
      <section v-else-if="activeTab === 'settings'" class="flex flex-col gap-5">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('KNOWLEDGE.TAB_SETTINGS') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('KNOWLEDGE.SETTINGS_HELP') }}
          </p>
        </div>
        <div class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
          <Input
            v-model="form.name"
            :label="t('KNOWLEDGE.NAME')"
            :max-length="100"
          />
          <TextArea
            v-model="form.description"
            :label="t('KNOWLEDGE.DESCRIPTION')"
            :max-length="2000"
            auto-height
          />
        </div>
      </section>
      <section v-else class="flex flex-col gap-5">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('KNOWLEDGE.TAB_ADVANCED') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('KNOWLEDGE.ADVANCED_HELP') }}
          </p>
        </div>
        <div class="flex flex-col gap-5 p-5 rounded-xl bg-n-solid-2">
          <div>
            <h3 class="font-medium text-n-slate-12">
              {{ t('KNOWLEDGE.RETRIEVAL') }}
            </h3>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('KNOWLEDGE.RETRIEVAL_HELP') }}
            </p>
          </div>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <Input
              v-model.number="form.similarity_threshold"
              type="number"
              min="0"
              max="1"
              step="0.01"
              :label="t('KNOWLEDGE.THRESHOLD')"
              :message="t('KNOWLEDGE.THRESHOLD_HELP')"
            /><Input
              v-model.number="form.retrieval_top_k"
              type="number"
              min="1"
              max="10"
              :label="t('KNOWLEDGE.TOP_K')"
              :message="t('KNOWLEDGE.TOP_K_HELP')"
            /><Input
              v-model.number="form.chunk_size"
              type="number"
              min="400"
              max="10000"
              :label="t('KNOWLEDGE.CHUNK_SIZE')"
            /><Input
              v-model.number="form.chunk_overlap"
              type="number"
              min="0"
              :label="t('KNOWLEDGE.CHUNK_OVERLAP')"
            />
          </div>
          <p v-if="changedChunking" class="text-sm text-n-amber-11">
            {{ t('KNOWLEDGE.REINDEX_WARNING') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('KNOWLEDGE.EMBEDDING_MODEL') }}
          </p>
        </div>
      </section>
    </div>
    <Dialog
      ref="documentDialog"
      width="2xl"
      :title="t('KNOWLEDGE.DOCUMENT_EDITOR')"
      :confirm-button-label="t('KNOWLEDGE.SAVE')"
      :disable-confirm-button="
        busy ||
        !documentDraft.name.trim() ||
        (!documentDraft.file && !documentDraft.content.trim())
      "
      @confirm="saveDocument"
    >
      <div class="flex flex-col gap-4">
        <Input
          v-model="documentDraft.name"
          :label="t('KNOWLEDGE.NAME')"
        /><input
          type="file"
          accept=".txt,.md,.pdf,text/plain,text/markdown,application/pdf"
          @change="documentDraft.file = $event.target.files[0]"
        /><TextArea
          v-if="!documentDraft.file"
          v-model="documentDraft.content"
          :label="t('KNOWLEDGE.MANUAL_TEXT')"
          :max-length="500000"
          auto-height
        />
      </div>
    </Dialog>
    <Dialog
      ref="documentDeletion"
      type="alert"
      :title="t('KNOWLEDGE.DELETE')"
      :description="
        t('KNOWLEDGE.DELETE_CONFIRM', { name: documentToDelete?.name })
      "
      :confirm-button-label="t('KNOWLEDGE.DELETE')"
      :cancel-button-label="t('KNOWLEDGE.CANCEL')"
      :disable-confirm-button="busy"
      :is-loading="busy"
      @confirm="removeDocument"
    />
    <Dialog
      ref="viewDialog"
      width="2xl"
      :title="extracted?.name"
      :show-confirm-button="false"
      :cancel-button-label="t('KNOWLEDGE.CLOSE')"
    >
      <pre
        class="max-h-96 overflow-y-auto whitespace-pre-wrap break-words text-sm text-n-slate-12"
        >{{ extracted?.content || t('KNOWLEDGE.NO_EXTRACTED_TEXT') }}</pre
      >
    </Dialog>
    <UnsavedChangesDialog ref="leaveDialog" />
    <Dialog
      ref="baseDeletion"
      type="alert"
      :title="t('KNOWLEDGE.DELETE')"
      :description="t('KNOWLEDGE.DELETE_CONFIRM', { name: base.name })"
      :confirm-button-label="t('KNOWLEDGE.DELETE')"
      :cancel-button-label="t('KNOWLEDGE.CANCEL')"
      :disable-confirm-button="busy"
      :is-loading="busy"
      @confirm="removeBase"
    />
  </div>
</template>
