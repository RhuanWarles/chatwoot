<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import api from 'dashboard/api/knowledgeBases';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n(); const router = useRouter(); const bases = ref([]); const error = ref(''); const busy = ref(false); const deletion = ref(null); const target = ref(null);
const load = async () => { try { bases.value = (await api.get()).data.bases; } catch { error.value = t('KNOWLEDGE.ERROR'); } };
const askDelete = base => { target.value = base; deletion.value.open(); };
const remove = async () => { busy.value = true; try { await api.delete(target.value.id); deletion.value.close(); await load(); } catch { error.value = t('KNOWLEDGE.ERROR'); } finally { busy.value = false; } };
onMounted(load);
</script>
<template>
  <main class="flex flex-col w-full gap-5"><header class="flex flex-wrap items-center justify-between gap-3"><div><h1 class="text-xl font-semibold text-n-slate-12">{{ t('KNOWLEDGE.TITLE') }}</h1><p class="text-sm text-n-slate-11">{{ t('KNOWLEDGE.HELP') }}</p></div><Button :label="t('KNOWLEDGE.CREATE')" @click="router.push({ name: 'knowledge_base_new' })" /></header><p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p><p v-if="!bases.length" class="text-sm text-n-slate-11">{{ t('KNOWLEDGE.EMPTY') }}</p><article v-for="base in bases" :key="base.id" class="flex flex-wrap items-start justify-between gap-4 p-5 rounded-xl bg-n-solid-2"><div class="min-w-0"><h2 class="text-base font-medium text-n-slate-12 break-words">{{ base.name }}</h2><p class="text-sm text-n-slate-11 break-words">{{ base.description }}</p><p class="text-xs text-n-slate-11">{{ t(base.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE') }} · {{ t('KNOWLEDGE.DOCUMENTS_COUNT', { count: base.documents_count }) }}</p><p class="text-xs text-n-slate-11">{{ t('KNOWLEDGE.AGENTS') }}: {{ base.agents.map(agent => agent.name).join(', ') || t('KNOWLEDGE.NONE') }}</p></div><div class="flex flex-wrap gap-2"><Button variant="faded" :label="t('KNOWLEDGE.EDIT')" @click="router.push({ name: 'knowledge_base_edit', params: { knowledgeBaseId: base.id } })" /><Button variant="ghost" color="ruby" :label="t('KNOWLEDGE.DELETE')" @click="askDelete(base)" /></div></article><Dialog ref="deletion" type="alert" :title="t('KNOWLEDGE.DELETE')" :description="t('KNOWLEDGE.DELETE_CONFIRM')" :confirm-button-label="t('KNOWLEDGE.DELETE')" :disable-confirm-button="busy" @confirm="remove" /></main>
</template>
