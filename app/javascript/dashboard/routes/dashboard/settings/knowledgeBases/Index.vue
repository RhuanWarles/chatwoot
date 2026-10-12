<script setup>
import { onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t, locale } = useI18n();
const bases = ref([]);
const selected = ref(null);
const documents = ref([]);
const error = ref('');
const busy = ref(false);
const baseDialog = ref(null);
const documentDialog = ref(null);
const viewDialog = ref(null);
const deletion = ref(null);
const draft = ref({});
const documentDraft = ref({});
const extracted = ref(null);
const deleteTarget = ref(null);
const query = ref('');
const sources = ref(null);
let timer;
const date = value =>
  new Date(value).toLocaleString(locale.value.replace('_', '-'));
const reportError = failure => {
  const code = failure.response?.data?.error;
  error.value = t(
    ['invalid_file', 'document_limit'].includes(code)
      ? `KNOWLEDGE.ERRORS.${code}`
      : 'KNOWLEDGE.ERROR'
  );
};
const load = async () => {
  const { data } = await api.get();
  bases.value = data.bases;
};
const loadDocuments = async () => {
  if (!selected.value) return;
  const id = selected.value.id;
  const { data } = await api.documents(id);
  if (selected.value?.id === id) documents.value = data.documents;
};
const run = async action => {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    await action();
  } catch (failure) {
    reportError(failure);
  } finally {
    busy.value = false;
  }
};
const editBase = base => {
  draft.value = base
    ? {
        id: base.id,
        name: base.name,
        description: base.description || '',
        active: base.active,
      }
    : { name: '', description: '', active: true };
  error.value = '';
  baseDialog.value.open();
};
const saveBase = () =>
  run(async () => {
    const { id, ...knowledge_base } = draft.value;
    if (id) await api.update(id, { knowledge_base });
    else await api.create({ knowledge_base });
    await load();
    baseDialog.value.close();
  });
const manage = base =>
  run(async () => {
    selected.value = base;
    sources.value = null;
    query.value = '';
    documents.value = [];
    await loadDocuments();
  });
const editDocument = document =>
  run(async () => {
    if (document) {
      const { data } = await api.document(selected.value.id, document.id);
      documentDraft.value = {
        id: data.id,
        name: data.name,
        content: data.source_type === 'manual' ? data.content : '',
        file: null,
      };
    } else documentDraft.value = { name: '', content: '', file: null };
    documentDialog.value.open();
  });
const saveDocument = () =>
  run(async () => {
    const draftDocument = documentDraft.value;
    let payload;
    if (draftDocument.file) {
      payload = new FormData();
      payload.append('document[name]', draftDocument.name);
      payload.append('document[file]', draftDocument.file);
    } else
      payload = {
        document: { name: draftDocument.name, content: draftDocument.content },
      };
    await api.saveDocument(selected.value.id, payload, draftDocument.id);
    await loadDocuments();
    await load();
    documentDialog.value.close();
  });
const view = document =>
  run(async () => {
    const { data } = await api.document(selected.value.id, document.id);
    extracted.value = data;
    viewDialog.value.open();
  });
const askDelete = (base, document = null) => {
  deleteTarget.value = { base, document };
  deletion.value.open();
};
const remove = () =>
  run(async () => {
    const { base, document } = deleteTarget.value;
    if (document) {
      await api.deleteDocument(base.id, document.id);
      await loadDocuments();
    } else {
      await api.delete(base.id);
      if (selected.value?.id === base.id) selected.value = null;
    }
    await load();
    deletion.value.close();
  });
const reindex = document =>
  run(async () => {
    await api.reindex(selected.value.id, document.id);
    await loadDocuments();
  });
const search = () =>
  run(async () => {
    const { data } = await api.search(selected.value.id, query.value);
    sources.value = data.sources;
  });
onMounted(() => {
  run(load);
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
  <main class="flex flex-col min-w-0 w-full gap-5 overflow-y-auto p-4">
    <header class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('KNOWLEDGE.TITLE') }}
      </h1>
      <Button :label="t('KNOWLEDGE.CREATE')" @click="editBase()" />
    </header>
    <p class="text-sm text-n-slate-11">{{ t('KNOWLEDGE.HELP') }}</p>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <p v-if="!bases.length && !busy" class="text-n-slate-11">
      {{ t('KNOWLEDGE.EMPTY') }}
    </p>
    <article
      v-for="base in bases"
      :key="base.id"
      class="p-4 rounded-xl border border-n-weak bg-n-solid-2"
    >
      <div class="flex flex-wrap justify-between gap-3">
        <div class="min-w-0">
          <h2 class="text-base font-medium text-n-slate-12 break-words">
            {{ base.name }}
          </h2>
          <p class="text-sm text-n-slate-11 break-words">
            {{ base.description }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t(base.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE') }} ·
            {{
              t('KNOWLEDGE.DOCUMENTS_COUNT', { count: base.documents_count })
            }}
            · {{ date(base.updated_at) }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('KNOWLEDGE.AGENTS') }}:
            {{
              base.agents.map(agent => agent.name).join(', ') ||
              t('KNOWLEDGE.NONE')
            }}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.DOCUMENTS')"
            :disabled="busy"
            @click="manage(base)"
          />
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.EDIT')"
            @click="editBase(base)"
          />
          <Button
            variant="ghost"
            color="ruby"
            :label="t('KNOWLEDGE.DELETE')"
            @click="askDelete(base)"
          />
        </div>
      </div>
    </article>
    <section
      v-if="selected"
      class="flex flex-col gap-4 p-4 rounded-xl border border-n-weak min-w-0"
    >
      <div class="flex flex-wrap justify-between gap-3">
        <h2 class="text-lg text-n-slate-12">
          {{ selected.name }} · {{ t('KNOWLEDGE.DOCUMENTS') }}
        </h2>
        <Button :label="t('KNOWLEDGE.ADD_DOCUMENT')" @click="editDocument()" />
      </div>
      <p v-if="!documents.length" class="text-n-slate-11">
        {{ t('KNOWLEDGE.NO_DOCUMENTS') }}
      </p>
      <article
        v-for="item in documents"
        :key="item.id"
        class="flex flex-wrap justify-between gap-3 p-3 rounded-lg bg-n-solid-2"
      >
        <div class="min-w-0">
          <strong class="text-sm text-n-slate-12 break-words">{{
            item.name
          }}</strong>
          <p class="text-xs text-n-slate-11">
            {{ item.source_type }} ·
            {{ t(`KNOWLEDGE.STATUS.${item.status}`) }} ·
            {{ t('KNOWLEDGE.CHUNKS', { count: item.chunks_count }) }} ·
            {{ date(item.updated_at) }}
          </p>
          <p v-if="item.status === 'failed'" class="text-xs text-n-ruby-11">
            {{
              t(
                `KNOWLEDGE.ERRORS.${item.error_code}`,
                t('KNOWLEDGE.ERRORS.indexing_failed')
              )
            }}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.VIEW')"
            @click="view(item)"
          />
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.EDIT')"
            @click="editDocument(item)"
          />
          <Button
            variant="ghost"
            :label="t('KNOWLEDGE.REINDEX')"
            :disabled="busy || item.status === 'processing'"
            @click="reindex(item)"
          />
          <Button
            variant="ghost"
            color="ruby"
            :label="t('KNOWLEDGE.DELETE')"
            @click="askDelete(selected, item)"
          />
        </div>
      </article>
      <form class="flex gap-2 flex-wrap" @submit.prevent="search">
        <Input
          v-model="query"
          class="flex-1"
          :placeholder="t('KNOWLEDGE.SEARCH_QUESTION')"
        />
        <Button
          type="submit"
          :label="t('KNOWLEDGE.SEARCH')"
          :disabled="busy || !query.trim()"
        />
      </form>
      <p v-if="sources && !sources.length" class="text-sm text-n-slate-11">
        {{ t('KNOWLEDGE.NO_RESULTS') }}
      </p>
      <article
        v-for="source in sources"
        :key="source.id"
        class="p-3 rounded-lg bg-n-alpha-2 min-w-0"
      >
        <p class="text-xs text-n-slate-11">
          {{ source.document }} · {{ source.score }}
        </p>
        <p class="text-sm whitespace-pre-wrap break-words text-n-slate-12">
          {{ source.content }}
        </p>
      </article>
    </section>
    <Dialog
      ref="baseDialog"
      :title="t(draft.id ? 'KNOWLEDGE.EDIT' : 'KNOWLEDGE.CREATE')"
      :confirm-button-label="t('KNOWLEDGE.SAVE')"
      :disable-confirm-button="busy || !draft.name?.trim()"
      @confirm="saveBase"
    >
      <div class="flex flex-col gap-4">
        <p v-if="error" role="alert" class="text-n-ruby-11">{{ error }}</p>
        <Input
          v-model="draft.name"
          :label="t('KNOWLEDGE.NAME')"
          :max-length="100"
        />
        <TextArea
          v-model="draft.description"
          :label="t('KNOWLEDGE.DESCRIPTION')"
          :max-length="2000"
        />
        <label class="flex gap-2 text-sm text-n-slate-12"
          ><input v-model="draft.active" type="checkbox" />{{
            t('KNOWLEDGE.ACTIVE')
          }}</label
        >
      </div>
    </Dialog>
    <Dialog
      ref="documentDialog"
      width="2xl"
      :title="t('KNOWLEDGE.ADD_DOCUMENT')"
      :confirm-button-label="t('KNOWLEDGE.SAVE')"
      :disable-confirm-button="
        busy ||
        !documentDraft.name?.trim() ||
        (!documentDraft.file && !documentDraft.content?.trim())
      "
      @confirm="saveDocument"
    >
      <div class="flex flex-col gap-4 max-h-96 overflow-y-auto">
        <p v-if="error" role="alert" class="text-n-ruby-11">{{ error }}</p>
        <Input
          v-model="documentDraft.name"
          :label="t('KNOWLEDGE.NAME')"
          :max-length="200"
        />
        <p class="text-xs text-n-slate-11">{{ t('KNOWLEDGE.UPLOAD_HELP') }}</p>
        <input
          type="file"
          accept=".txt,.md,.pdf,text/plain,text/markdown,application/pdf"
          class="text-sm text-n-slate-12"
          @change="documentDraft.file = $event.target.files[0]"
        />
        <TextArea
          v-if="!documentDraft.file"
          v-model="documentDraft.content"
          :label="t('KNOWLEDGE.MANUAL_TEXT')"
          :max-length="500000"
          :resize="true"
        />
      </div>
    </Dialog>
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
    <Dialog
      ref="deletion"
      type="alert"
      :title="t('KNOWLEDGE.DELETE')"
      :description="t('KNOWLEDGE.DELETE_CONFIRM')"
      :confirm-button-label="t('KNOWLEDGE.DELETE')"
      :disable-confirm-button="busy"
      @confirm="remove"
    >
      <p v-if="error" class="text-n-ruby-11">{{ error }}</p>
    </Dialog>
  </main>
</template>
