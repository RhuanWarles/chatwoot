# Passo a passo: layout "lista + detalhe" (estilo Vapi) para Assistentes, Ferramentas e Base de conhecimento

Guia para levar o layout novo destas três telas para outro sistema que também usa o Chatwoot como base e **já tem a
lógica pronta** (APIs, formulários, regras). Aqui só muda a **casca**: como a tela é organizada, como se navega entre os
itens e como se edita. Nada de backend.

Código de referência: branch `feat/ai-master-detail`, pasta
`app/javascript/dashboard/routes/dashboard/settings/` (subpastas `aiShared`, `aiAgents`, `aiTools`, `knowledgeBases`).
Tudo abaixo foi copiado do que está funcionando e testado lá.

---

## 0. Como fica

```
┌────────────────────────┬──────────────────────────────────────────────┐
│ LISTA (17,5rem)        │ DETALHE (resto da largura)                   │
│ Título  [12]           │ ┌─ cabeçalho fixo ─────────────────────────┐ │
│ [+ Criar]              │ │ ←  Nome  (●) Ativo  ID 7      Descartar  │ │
│ [Buscar…] [Status ▾]   │ │    subtítulo       Salvar  ⋮             │ │
│ ┌────────────────────┐ │ └──────────────────────────────────────────┘ │
│ │ Nome do item     ● │ │ [ Aba 1 | Aba 2 | Aba 3 ]   (ou seções)      │
│ │ resumo da linha    │ │  conteúdo do item aberto                     │
│ └────────────────────┘ │                                              │
│ …                      │                                              │
└────────────────────────┴──────────────────────────────────────────────┘
```

Regras de comportamento (são o que "dá a cara" da Vapi):

1. A URL carrega o item aberto: `/settings/ai-agents/12`. Link direto e botão voltar funcionam.
2. Entrar na tela sem id **abre o item mais recente** (no celular mostra só a lista).
3. Id que não existe → troca (replace) para o item mais recente.
4. Criar **não é mais uma página**: abre um modal; ao criar, o item aparece no topo da lista e já fica aberto.
5. Editar é o próprio detalhe. Botões **Descartar** e **Salvar** no cabeçalho; o interruptor Ativo/Inativo salva na hora.
6. Excluir (menu ⋮) abre o próximo item da lista (ou o anterior; ou o estado vazio).
7. Trocar de item ou sair da tela com alterações não salvas pede confirmação.
8. Lista e detalhe rolam separados. Abaixo de `md` (768px) aparece **um por vez**: a lista, ou o detalhe com um botão ← para voltar.
9. Estados: esqueleto enquanto carrega, erro com "Tentar novamente", vazio com botão de criar.

---

## 1. Pré-requisitos (já existem no Chatwoot base)

- Vue 3 (`<script setup>`), `vue-router` 4, `@vueuse/core`, `vue-i18n`, Tailwind com os tokens do Chatwoot (`n-slate-12`,
  `n-weak`, `n-solid-2`, `n-alpha-1`…).
- Componentes de `dashboard/components-next/`: `button/Button.vue`, `input/Input.vue`, `textarea/TextArea.vue`,
  `switch/Switch.vue`, `popover/Popover.vue`, `dropdown-menu/DropdownMenu.vue`, `dialog/Dialog.vue`.
- Ícones `i-lucide-*` (já usados no Chatwoot).
- `dashboard/composables` → `useAlert`; `dashboard/composables/useAccount` → `accountId`; `shared/helpers/clipboard`.

Se alguma tela do outro sistema usar versões antigas desses componentes, ajuste só os nomes de props (`variant`, `size`,
`icon`, `label`, `is-loading`).

---

## 2. Passo 1: copiar os blocos compartilhados (`aiShared/`)

Crie a pasta `routes/dashboard/settings/aiShared/` e copie os 11 arquivos (código completo no **Anexo A**):

| Arquivo | Para que serve |
|---|---|
| `MasterDetailLayout.vue` | Casca de duas colunas; abaixo de `md` mostra só uma. Recebe `show-detail`. |
| `masterDetail.js` | Regras: ordenar do mais novo ao mais antigo, decidir para onde ir, próximo item após excluir, redirecionamento. |
| `useUnsavedChangesGuard.js` | Pergunta antes de sair/trocar de item com alterações. |
| `UnsavedChangesDialog.vue` | O modal "Descartar alterações não salvas?". |
| `EmptyRoute.js` | Componente vazio da rota índice (a tela decide o que mostrar). |
| `DetailSkeleton.vue` / `ListSkeleton.vue` | Esqueletos de carregamento. |
| `DetailState.vue` | Estado vazio e de erro do painel. |
| `CollapsibleSection.vue` | Seção que abre/fecha (usada nas Ferramentas). |
| `CopyIdButton.vue` | Botão "ID 12 ⧉" que copia o id. |

Textos que esses arquivos usam (chave `AI_HUB.*`, adicione nos seus arquivos de tradução):

| Chave | pt-BR | en |
|---|---|---|
| `LOADING` | Carregando... | Loading... |
| `ID` | ID | ID |
| `COPY_ID` | Copiar ID | Copy ID |
| `ID_COPIED` | ID copiado. | ID copied. |
| `ID_COPY_ERROR` | Não foi possível copiar o ID. | Could not copy the ID. |
| `BACK_TO_LIST` | Voltar para a lista | Back to the list |
| `DISCARD` | Descartar | Discard |
| `UNSAVED_TITLE` | Descartar alterações não salvas? | Discard unsaved changes? |
| `UNSAVED_CONFIRM` | Você tem alterações que não foram salvas. Se sair agora, elas serão perdidas. | You have changes that were not saved. If you leave now they will be lost. |
| `UNSAVED_LEAVE` | Descartar e sair | Discard and leave |
| `UNSAVED_STAY` | Continuar editando | Keep editing |

---

## 3. Passo 2: rotas (uma tela = uma rota-pai com filhos)

A rota-pai é a **lista** (`Index.vue`). Os filhos são o **item aberto**. O `Index` fica montado o tempo todo e só o
filho troca. Isso é o que impede a lista de piscar ao navegar.

Exemplo da Base de conhecimento (`knowledgeBases.routes.js`). Assistentes e Ferramentas seguem **exatamente** o mesmo molde:

```js
import { frontendURL } from '../../../../helper/URLHelper';
import EmptyRoute from '../aiShared/EmptyRoute';
import Index from './Index.vue';
import KnowledgeBaseDetailRoute from './KnowledgeBaseDetailRoute.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/knowledge-bases'),
      component: Index,                       // a lista
      meta,
      children: [
        { path: '', name: 'knowledge_bases_settings', component: EmptyRoute, meta },
        {
          path: ':knowledgeBaseId(\\d+)',      // só números: "new" e "logs" não caem aqui
          name: 'knowledge_base_detail',
          component: KnowledgeBaseDetailRoute,
          props: true,
          meta,
        },
        // Links antigos continuam funcionando:
        { path: 'new', redirect: { name: 'knowledge_bases_settings' } },
        {
          path: ':knowledgeBaseId(\\d+)/edit',
          redirect: to => ({ name: 'knowledge_base_detail', params: to.params }),
        },
      ],
    },
  ],
};
```

Nomes e parâmetros usados nas três telas:

| Tela | Caminho | Nome do índice | Nome do detalhe | Param |
|---|---|---|---|---|
| Assistentes | `/settings/ai-agents` | `ai_agents_settings` | `ai_agent_detail` | `agentId` |
| Ferramentas | `/settings/ai-tools` | `ai_tools_settings` | `ai_tool_detail` | `toolId` |
| Base de conhecimento | `/settings/knowledge-bases` | `knowledge_bases_settings` | `knowledge_base_detail` | `knowledgeBaseId` |

Particularidades:

- **Ferramentas** tem um filho extra `logs` (`ai_tool_logs`), declarado **antes** de `:toolId(\\d+)`. Os logs abrem no painel da direita.
- **Assistentes** tem uma rota separada `.../:agentId/playground` (`ai_agent_playground`) dentro do `SettingsWrapper`
  com `meta: { fullHeight: true, wide: true }`, porque o teste de conversa precisa de tela cheia.
- Estas rotas usam o `Index` direto como componente (sem `SettingsWrapper`): o layout ocupa toda a área (`h-full`).
  Se no outro sistema as páginas de configurações ficam dentro de um wrapper com padding, a rota-pai precisa ficar fora dele.

---

## 4. Passo 3: a lista (`Index.vue`) e o "workspace"

O `Index` faz 4 coisas: carrega a lista, ordena, decide o que está aberto e **compartilha a lista com o detalhe** via
`provide` (assim criar/editar/excluir no detalhe atualiza o painel esquerdo sem recarregar).

`workspace.js` (uma linha):

```js
export const KNOWLEDGE_WORKSPACE = 'knowledgeBasesWorkspace';
```

`Index.vue` (script) — o miolo é igual nas 3 telas; troque `bases`/`api` pelo que a tela lista:

```vue
<script setup>
import { computed, provide, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { breakpointsTailwind, useBreakpoints } from '@vueuse/core';
import api from 'dashboard/api/knowledgeBases';            // a API que o seu sistema já tem
import { useAccount } from 'dashboard/composables/useAccount';
import { nextAfterRemoval, sortNewestFirst, useMasterDetailRedirect } from '../aiShared/masterDetail';
import { KNOWLEDGE_WORKSPACE } from './workspace';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const isMobile = useBreakpoints(breakpointsTailwind).smaller('md');

const bases = ref([]);          // sempre do mais novo ao mais antigo
const loading = ref(true);
const loaded = ref(false);       // só depois disso a URL é julgada
const loadError = ref('');
const paused = ref(false);       // pausa o redirecionamento durante uma exclusão
const search = ref('');
const status = ref('all');       // all | active | inactive
const createDialog = ref(null);
let loadRequest = 0;             // descarta resposta antiga se a conta mudar

const selectedId = computed(() => route.params.knowledgeBaseId);
const selectedBase = computed(() =>
  bases.value.find(base => String(base.id) === String(selectedId.value))
);

const filteredBases = computed(() => {
  const query = search.value.trim().toLowerCase();
  return bases.value.filter(base => {
    const okStatus = status.value === 'all' || (status.value === 'active' ? base.active : !base.active);
    const okSearch = !query || [base.name, base.description].some(v => String(v || '').toLowerCase().includes(query));
    return okStatus && okSearch;
  });
});

const indexLocation = () => ({ name: 'knowledge_bases_settings', params: { accountId: accountId.value } });
const detailLocation = id => ({ name: 'knowledge_base_detail', params: { accountId: accountId.value, knowledgeBaseId: id } });
const isSelected = base => String(base.id) === String(selectedId.value);

const load = async () => {
  loadRequest += 1;
  const request = loadRequest;
  loading.value = true; loaded.value = false; loadError.value = ''; bases.value = [];
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

// Mantém o painel esquerdo em dia depois de salvar/criar/ativar, sem recarregar a lista.
const upsert = base => {
  bases.value = sortNewestFirst([...bases.value.filter(item => item.id !== base.id), base]);
};

// Excluir: abre o próximo (ou o anterior). O redirecionamento fica pausado para não brigar com esta navegação.
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

const goToList = () => router.push(indexLocation());               // botão ← no celular
const onCreated = base => { upsert(base); router.push(detailLocation(base.id)); };

watch(accountId, () => load(), { immediate: true });

useMasterDetailRedirect({
  items: bases, loaded, selectedId,
  atIndex: computed(() => route.name === 'knowledge_bases_settings'),
  isMobile, paused, detailLocation, indexLocation,
});

provide(KNOWLEDGE_WORKSPACE, { bases, upsert, removeBase, goToList });
</script>
```

`Index.vue` (template) — lista à esquerda, detalhe à direita:

```vue
<template>
  <div class="flex w-full h-full min-h-0">
    <MasterDetailLayout :show-detail="Boolean(selectedId)">
      <template #master>
        <div class="flex flex-col gap-3 p-4 border-b border-n-weak">
          <h1 class="flex items-center gap-2 text-heading-3 text-n-slate-12">
            {{ t('KNOWLEDGE.TITLE') }}
            <span class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11">{{ bases.length }}</span>
          </h1>
          <Button :label="t('KNOWLEDGE.CREATE')" icon="i-lucide-plus" :disabled="!loaded || Boolean(loadError)" @click="createDialog.open()" />
          <template v-if="bases.length">
            <Input v-model="search" size="sm" :placeholder="t('KNOWLEDGE.SEARCH_BASES_PLACEHOLDER')" :aria-label="t('KNOWLEDGE.SEARCH_BASES')" />
            <select v-model="status" :aria-label="t('KNOWLEDGE.STATUS_FILTER')"
              class="h-8 px-3 mb-0 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12">
              <option value="all">{{ t('KNOWLEDGE.ALL_STATUS') }}</option>
              <option value="active">{{ t('KNOWLEDGE.ACTIVE') }}</option>
              <option value="inactive">{{ t('KNOWLEDGE.INACTIVE') }}</option>
            </select>
          </template>
        </div>

        <ListSkeleton v-if="loading" />
        <DetailState v-else-if="loadError" is-error :title="loadError" :action-label="t('KNOWLEDGE.RETRY')" @action="load" />
        <nav v-else class="flex flex-col flex-1 min-h-0 gap-1 p-3 overflow-y-auto" :aria-label="t('KNOWLEDGE.LIST_LABEL')">
          <p v-if="bases.length && !filteredBases.length" class="p-3 text-sm text-n-slate-11">{{ t('KNOWLEDGE.EMPTY_FILTERED') }}</p>
          <RouterLink v-for="base in filteredBases" :key="base.id" :to="detailLocation(base.id)"
            class="flex flex-col gap-1 p-3 transition-colors border rounded-xl"
            :class="isSelected(base) ? 'bg-n-solid-2 border-n-strong' : 'border-transparent hover:bg-n-alpha-1'"
            :aria-current="isSelected(base) ? 'page' : undefined">
            <span class="flex items-center justify-between gap-2">
              <span class="font-semibold truncate text-n-slate-12">{{ base.name }}</span>
              <!-- bolinha de status: verde = ativo, cinza = inativo -->
              <span class="size-2 rounded-full shrink-0" :class="base.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
                role="img" :aria-label="t(base.active ? 'KNOWLEDGE.ACTIVE' : 'KNOWLEDGE.INACTIVE')" />
            </span>
            <span class="text-sm truncate text-n-slate-11"><!-- resumo de uma linha do item --></span>
          </RouterLink>
        </nav>
      </template>

      <!-- Painel da direita: um destes quatro estados -->
      <DetailSkeleton v-if="loading || (loaded && bases.length && !selectedBase)" />
      <DetailState v-else-if="loaded && !bases.length" :title="t('KNOWLEDGE.EMPTY')" :description="t('KNOWLEDGE.EMPTY_HELP')"
        :action-label="t('KNOWLEDGE.CREATE')" action-icon="i-lucide-plus" @action="createDialog.open()" />
      <router-view v-else-if="selectedBase" v-slot="{ Component }">
        <component :is="Component" :key="selectedId" />   <!-- :key refaz o detalhe ao trocar de item -->
      </router-view>
    </MasterDetailLayout>

    <KnowledgeBaseCreateDialog ref="createDialog" @created="onCreated" />
  </div>
</template>
```

O que cada tela põe no cartão da lista (a linha de resumo):

| Tela | Linha 1 | Linha 2 |
|---|---|---|
| Assistentes | nome + bolinha de status | `provedor · modelo` |
| Ferramentas | nome + bolinha de status | selo do método (GET/POST…) + URL |
| Base de conhecimento | nome + bolinha de status | `N documentos · N assistentes` |

Extras de cada lista:

- **Assistentes**: no topo, abas **Texto | Voz** (`role="tablist"`) que guardam a escolha em `?type=`; no rodapé do painel
  esquerdo ficam os atalhos "Uso de IA" (link) e "Conexão do provedor de texto" (abre modal). Se o seu sistema não usa
  voz, remova as abas e fixe `type = 'text'`.
- **Ferramentas**: ao lado do título há o botão **Logs** (`router.push({ name: 'ai_tool_logs' })`). Com a rota de logs
  ativa, o `Index` usa `show-detail="Boolean(selectedId) || isLogsRoute"` e renderiza `<router-view v-if="isLogsRoute" />`
  **antes** dos estados de esqueleto.

---

## 5. Passo 4: o detalhe (o que você converte da sua página de edição)

Duas peças por tela:

**a) Wrapper da rota** (`KnowledgeBaseDetailRoute.vue`) — pega o item da lista compartilhada:

```vue
<script setup>
import { computed, inject } from 'vue';
import KnowledgeBaseDetail from './KnowledgeBaseDetail.vue';
import { KNOWLEDGE_WORKSPACE } from './workspace';

const props = defineProps({ knowledgeBaseId: { type: String, required: true } });
const workspace = inject(KNOWLEDGE_WORKSPACE);
const base = computed(() => workspace.bases.value.find(item => String(item.id) === props.knowledgeBaseId));
</script>

<template>
  <KnowledgeBaseDetail v-if="base" :base="base" />
  <div v-else />
</template>
```

(Em Assistentes o wrapper `AgentDetail.vue` ainda escolhe entre `TextAgentDetail` e `VoiceAgentDetail` pelo tipo.)

**b) O detalhe** (`XxxDetail.vue`): é a **sua página de edição atual**, com três mudanças:

1. Tirar o "chrome" de página (breadcrumb, botão voltar, `SettingsWrapper`, título grande, botão "Cancelar"). O conteúdo
   continua sendo o mesmo formulário.
2. Colocar o **cabeçalho fixo** abaixo no topo.
3. Trocar o "salvar e voltar para a lista" por **salvar e continuar no item** (`workspace.upsert(salvo)`).

Cabeçalho (igual nas três telas; só mudam os textos e o botão "Testar", que existe em Assistentes e Ferramentas):

```vue
<header class="sticky top-0 z-20 flex flex-wrap items-center justify-between gap-4 px-6 py-4 border-b border-n-weak bg-n-surface-1">
  <div class="flex items-start min-w-0 gap-2">
    <!-- só no celular: volta para a lista -->
    <Button class="md:hidden" variant="ghost" size="sm" icon="i-lucide-arrow-left"
      :aria-label="t('AI_HUB.BACK_TO_LIST')" @click="workspace.goToList()" />
    <div class="min-w-0">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
        <h2 class="text-heading-1 text-n-slate-12 break-words">{{ form.name || item.name }}</h2>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <Switch :model-value="form.active" :disabled="busy" @update:model-value="toggleActive" />
          {{ form.active ? t('X.ACTIVE') : t('X.INACTIVE') }}
        </label>
        <CopyIdButton :id="item.id" />
      </div>
      <p class="text-sm text-n-slate-11"><!-- subtítulo: descrição ou contadores --></p>
    </div>
  </div>

  <div class="flex flex-wrap items-center gap-2">
    <span v-if="isDirty" class="text-xs text-n-amber-11">{{ t('X.UNSAVED') }}</span>
    <Button variant="ghost" :label="t('AI_HUB.DISCARD')" :disabled="!isDirty || busy" @click="discard" />
    <!-- Assistentes/Ferramentas: <Button variant="faded" icon="i-lucide-flask-conical | i-lucide-play" :label="Testar" …/> -->
    <Button :label="t('X.SAVE')" :is-loading="busy" :disabled="!isDirty || busy || !canSave" @click="save" />
    <Popover align="end">
      <Button icon="i-lucide-ellipsis-vertical" variant="ghost" size="sm" :disabled="busy" :aria-label="t('X.MORE')" />
      <template #content="{ hide }">
        <DropdownMenu class="!relative w-56 max-w-[calc(100vw-2rem)]" :menu-items="actionMenuItems" @action="handleMenuAction($event, hide)" />
      </template>
    </Popover>
  </div>
</header>

<div class="flex flex-col gap-5 p-6"> <!-- corpo: abas ou seções --> </div>
```

> O `<section>` do `MasterDetailLayout` é quem rola (`overflow-y-auto`). Por isso `sticky top-0` no cabeçalho funciona:
> ele fica preso no topo do painel da direita, não da página.

A lógica do detalhe (o que faz o "Descartar/Salvar" se comportar):

```js
const savedItem = ref(props.item);                 // última versão salva: para onde o "Descartar" volta
const form = ref(formFromItem(props.item));        // o que a pessoa está editando
const snapshot = () => JSON.stringify(form.value); // (na Base de conhecimento inclui também os arquivos pendentes)
const savedSnapshot = ref(snapshot());
const removed = ref(false);
const isDirty = computed(() => !removed.value && snapshot() !== savedSnapshot.value);

const discard = () => { form.value = formFromItem({ ...savedItem.value, active: form.value.active }); };

// Ativar/desativar salva na hora (não entra em "alterações não salvas")
const toggleActive = async () => {
  if (busy.value) return;
  busy.value = true;
  const previous = form.value.active;
  form.value.active = !previous;
  try {
    const { data } = await api.update(props.item.id, { item: { active: !previous } });
    savedItem.value = { ...savedItem.value, ...data };
    workspace.upsert(savedItem.value);              // atualiza a bolinha na lista
  } catch {
    form.value.active = previous;                   // desfaz se falhar
    useAlert(t('X.ERROR'));
  } finally { busy.value = false; }
};

// Excluir: marca removed (para não perguntar "descartar?") e deixa a lista escolher o próximo
const removeItem = () => run(async () => {
  await api.delete(props.item.id);
  removed.value = true;
  deletionDialog.value.close();
  await workspace.removeItem(props.item.id);        // no Index: removeBase / removeTool / removeAgent
});

useUnsavedChangesGuard(isDirty, leaveDialog);        // leaveDialog = ref do <UnsavedChangesDialog ref="leaveDialog" />
```

E no fim do template: `<UnsavedChangesDialog ref="leaveDialog" />` e o `Dialog` de confirmação de exclusão.

O que vai no corpo de cada tela (o formulário é o que o seu sistema já tem; só reorganize):

| Tela | Estrutura do corpo |
|---|---|
| Assistentes | 4 abas: **Geral · Instruções · Comportamento · Conexões** (inbox, ferramentas e bases ligadas ao assistente). Botão **Testar** leva para `ai_agent_playground`. Menu ⋮: memórias, excluir. |
| Ferramentas | 5 seções recolhíveis (`CollapsibleSection`): **Informações básicas · Parâmetros · Requisição · Uso (quais assistentes usam) · Logs recentes**. Botão **Testar** abre modal (`ToolTestDialog`). Subtítulo: "usada por N assistentes". Menu ⋮: só excluir. |
| Base de conhecimento | 4 abas: **Documentos · Busca · Configurações · Avançado**. Documentos: arrastar-e-soltar arquivos + "Adicionar texto"; a lista atualiza sozinha a cada 15 s enquanto houver documento em processamento. |

Barra de abas (usada em Assistentes e Base de conhecimento):

```vue
<nav class="flex gap-1 p-1 overflow-x-auto rounded-xl bg-n-solid-2" :aria-label="t('X.TABS')">
  <button v-for="[key, label] in tabs" :key="key" type="button"
    class="px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap"
    :class="activeTab === key ? 'bg-n-solid-1 text-n-slate-12 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12'"
    :aria-current="activeTab === key ? 'page' : undefined" @click="activeTab = key">
    {{ t(label) }}
  </button>
</nav>
```

---

## 6. Passo 5: criar em modal (substitui a página "Novo")

Um `XxxCreateDialog.vue` por tela, com **só os campos obrigatórios** (nome; na Base de conhecimento, nome + descrição).
Expõe `open()` e emite `created` com o item que a API devolveu:

```vue
<script setup>
const emit = defineEmits(['created']);
const dialog = ref(null); const busy = ref(false); const error = ref('');
const draft = ref({ ...DEFAULTS });
const canSave = computed(() => Boolean(draft.value.name.trim()));

const open = () => { error.value = ''; draft.value = { ...DEFAULTS }; dialog.value.open(); };
const create = async () => {
  if (!canSave.value || busy.value) return;
  busy.value = true; error.value = '';
  try {
    const { data } = await api.create({ knowledge_base: { ...draft.value } });
    dialog.value.close();
    emit('created', data);                 // o Index faz upsert + abre o item
  } catch { error.value = t('KNOWLEDGE.ERROR'); }
  finally { busy.value = false; }
};
defineExpose({ open });
</script>

<template>
  <Dialog ref="dialog" width="2xl" overflow-y-auto :title="t('KNOWLEDGE.CREATE_TITLE')" :is-loading="busy"
    :disable-confirm-button="!canSave || busy" :confirm-button-label="t('KNOWLEDGE.CREATE_CONFIRM')"
    :cancel-button-label="t('KNOWLEDGE.CANCEL')" @confirm="create">
    <div class="flex flex-col gap-4 p-1">
      <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
      <Input v-model="draft.name" :label="t('KNOWLEDGE.NAME')" :max-length="100" :disabled="busy" />
      <!-- demais campos obrigatórios do seu sistema -->
    </div>
  </Dialog>
</template>
```

Os demais campos (os opcionais) ficam no detalhe, onde a pessoa cai logo depois de criar.

---

## 7. Passo 6: menu lateral

O item do menu precisa ficar **destacado** também quando a rota é a do detalhe (nome diferente do índice). No
`Sidebar.vue`, acrescente os nomes novos em `activeOn`:

```js
{ name: 'Assistants', to: accountScopedRoute('ai_agents_settings'),
  activeOn: ['ai_agents_settings', 'ai_agent_detail', 'saas_ai_settings'] },
{ name: 'Tools', to: accountScopedRoute('ai_tools_settings'),
  activeOn: ['ai_tools_settings', 'ai_tool_detail', 'ai_tool_logs'] },
{ name: 'Knowledge bases', to: accountScopedRoute('knowledge_bases_settings'),
  activeOn: ['knowledge_bases_settings', 'knowledge_base_detail'] },
```

Sem isso o item some do destaque assim que um item é aberto (a URL deixa de ser a do índice).

---

## 8. Passo 7: apagar o que ficou sem uso

Depois que o detalhe funcionar: remover as páginas antigas de edição/criação (`...EditorPage.vue`, `...TextAgents.vue`,
`...VoiceAgents.vue`) e os testes delas; manter só as redireções de rotas antigas do Passo 2.

---

## 9. Receita das medidas e classes (para manter o visual idêntico)

| Onde | Classes |
|---|---|
| Casca | `flex w-full h-full min-h-0 bg-n-surface-1` |
| Lista (esquerda) | `w-full md:w-[17.5rem] md:shrink-0 border-e border-n-weak` (some em telas pequenas quando há item aberto) |
| Detalhe (direita) | `flex-1 min-w-0 min-h-0 overflow-y-auto` |
| Cartão da lista | `p-3 border rounded-xl transition-colors`; selecionado `bg-n-solid-2 border-n-strong`; normal `border-transparent hover:bg-n-alpha-1` |
| Bolinha de status | `size-2 rounded-full` + `bg-n-teal-9` (ativo) / `bg-n-slate-9` (inativo) |
| Contador no título | `px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-slate-11` |
| Cabeçalho do detalhe | `sticky top-0 z-20 px-6 py-4 border-b border-n-weak bg-n-surface-1` |
| Corpo do detalhe | `flex flex-col gap-5 p-6` |
| Aviso "não salvo" | `text-xs text-n-amber-11` |
| Seção (Ferramentas) | `rounded-xl bg-n-solid-2`, cabeçalho `p-5`, conteúdo `px-5 pb-5` |

---

## 10. Checklist de validação (rode isto antes de dar por pronto)

Em cada uma das três telas:

- [ ] Abrir `/settings/<tela>` sem id → abre o item **mais recente**, com o id na URL; a lista mostra o item destacado.
- [ ] Botão voltar do navegador sai da tela (não fica preso em loop); avançar também.
- [ ] `/settings/<tela>/99999` (id que não existe) → vira o mais recente (sem empilhar histórico).
- [ ] `/new` e `/:id/edit` (links antigos) redirecionam.
- [ ] Criar → modal → o item aparece **no topo** da lista, já aberto, sem recarregar a página.
- [ ] Editar um campo → aparece "alterações não salvas", **Salvar** habilita; **Descartar** volta ao valor salvo.
- [ ] Com alteração pendente, clicar em outro item/menu → pede confirmação; "Continuar editando" mantém, "Descartar e sair" vai.
- [ ] Fechar/recarregar a aba com alteração pendente → aviso do navegador.
- [ ] Salvar atualiza o nome/resumo no painel esquerdo sem recarregar.
- [ ] Interruptor Ativo/Inativo salva na hora e a bolinha da lista muda; falha desfaz o interruptor.
- [ ] Excluir → abre o item de baixo (ou o de cima) e some da lista; se era o último, aparece o estado vazio.
- [ ] Lista vazia → estado vazio com botão de criar, e a URL fica no índice (não entra em loop).
- [ ] Carregando → esqueletos (nunca o estado vazio). Falha de rede → erro com "Tentar novamente".
- [ ] Busca e filtro de status na lista não mexem na URL.
- [ ] Celular (≤ 767px): entra mostrando **só a lista**; tocar num item mostra só o detalhe; ← volta para a lista.
- [ ] Item do menu lateral continua destacado com um item aberto.
- [ ] Assistentes: botão Testar abre a tela de teste em tela cheia. Ferramentas: Logs abre no painel direito.
      Base de conhecimento: envio de arquivo e polling de documentos em processamento.

---

## 11. Armadilhas que já apareceram (evite)

1. **`router.replace`, nunca `push`**, nos redirecionamentos automáticos. Com `push`, o botão voltar fica em loop.
2. **Só julgue a URL depois que a lista carregou** (`loaded`). Antes disso todo link direto parece inválido.
3. **Pause o redirecionamento ao excluir** (`paused`), senão ele disputa com a navegação para o próximo item.
4. **`:key="selectedId"` no `component` do `router-view`**, senão o formulário de um item aparece com dados do anterior.
5. **O guard precisa de dois ganchos**: `onBeforeRouteLeave` (sair da tela) e `onBeforeRouteUpdate` (trocar de item: a
   rota é a mesma, só muda o `:id`). O `useUnsavedChangesGuard` já faz os dois.
6. **Id da rota é string** e o id do item é número: compare sempre com `String(a) === String(b)`.
7. **Rota `logs` antes de `:toolId(\\d+)`** — e o `(\\d+)` nos params — para "logs"/"new" não serem tratados como id.
8. **Atualize a lista pela lista compartilhada** (`workspace.upsert`), não recarregando a API, ou o painel esquerdo pisca.
9. **No Playground (Assistentes)**, devolva o foco ao campo de mensagem depois de enviar (a tela de teste perdia o cursor).
10. **Lista sem `created_at`** (Ferramentas): `sortNewestFirst` desempata por `id`, então funciona sem a data.
11. Se o outro sistema renderiza a tela dentro de um contêiner com padding/rolagem próprios, o layout de duas colunas
    perde a altura: a rota-pai precisa de `h-full min-h-0` até a raiz.

---

## 12. Ordem sugerida de trabalho (da mais simples para a mais complexa)

1. Copiar `aiShared/` + traduções `AI_HUB.*` (Passo 1).
2. **Base de conhecimento** (a mais simples: lista, 4 abas, upload) — valida o molde inteiro.
3. **Ferramentas** (adiciona seções recolhíveis, rota de logs e modal de teste).
4. **Assistentes** (adiciona abas Texto/Voz, conexões, rota de teste em tela cheia).
5. Menu lateral (Passo 6) e limpeza (Passo 7).
6. Checklist (seção 10) em cada tela.

Arquivos-fonte equivalentes na branch `feat/ai-master-detail`, para comparar:

| Tela | Lista | Detalhe | Criação | Rotas |
|---|---|---|---|---|
| Base de conhecimento | `knowledgeBases/Index.vue` | `KnowledgeBaseDetail.vue` (+ `...DetailRoute.vue`) | `KnowledgeBaseCreateDialog.vue` | `knowledgeBases.routes.js`, `workspace.js`, `form.js` |
| Ferramentas | `aiTools/Index.vue` | `ToolDetail.vue` (+ `ToolDetailRoute.vue`), `Logs.vue`, `ToolTestDialog.vue` | `ToolCreateDialog.vue` | `aiTools.routes.js`, `workspace.js`, `form.js` |
| Assistentes | `aiAgents/Index.vue` | `AgentDetail.vue`, `TextAgentDetail.vue`, `VoiceAgentDetail.vue`, `Playground.vue` | `AgentCreateDialog.vue` | `aiAgents.routes.js`, `workspace.js`, `form.js` |

Os testes (`specs/`) de cada pasta descrevem o comportamento esperado e podem ser copiados junto.

---

## Anexo A: código completo de `aiShared/`

### `MasterDetailLayout.vue`

```vue
<script setup>
// Two independently scrolling panels using the whole content area. Below `md` only one is shown:
// the list, or the detail once an item is open.
defineProps({
  showDetail: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div class="flex w-full h-full min-h-0 bg-n-surface-1">
    <aside
      class="flex-col w-full min-h-0 border-e md:w-[17.5rem] md:shrink-0 border-n-weak"
      :class="showDetail ? 'hidden md:flex' : 'flex'"
    >
      <slot name="master" />
    </aside>
    <section
      class="flex-col flex-1 min-w-0 min-h-0 overflow-y-auto"
      :class="showDetail ? 'flex' : 'hidden md:flex'"
    >
      <slot />
    </section>
  </div>
</template>
```

### `masterDetail.js`

```js
import { watch } from 'vue';
import { useRouter } from 'vue-router';

const createdAt = item =>
  (item.created_at ? Date.parse(item.created_at) : 0) || 0;

// Newest first. `id` breaks ties and covers payloads without `created_at` (the tools list).
export const sortNewestFirst = items =>
  [...items].sort((a, b) => createdAt(b) - createdAt(a) || b.id - a.id);

const sameId = (item, id) => String(item.id) === String(id);

// Where a master-detail screen has to go once its list is known. `null` keeps the URL as it is,
// `{ id }` replaces it with that item and `{ id: null }` replaces it with the index.
// `items` must already be sorted newest first.
export const resolveSelection = ({ items, selectedId, atIndex, isMobile }) => {
  if (selectedId) {
    if (items.some(item => sameId(item, selectedId))) return null;
    return { id: items[0]?.id ?? null };
  }
  // Phones show the list first; everywhere else the index opens the newest item.
  return atIndex && items.length && !isMobile ? { id: items[0].id } : null;
};

// Item to open once `removedId` is deleted: the one below it in the list, else the one above.
export const nextAfterRemoval = (items, removedId) => {
  const index = items.findIndex(item => sameId(item, removedId));
  if (index === -1) return null;
  return items[index + 1] || items[index - 1] || null;
};

// Applies `resolveSelection` with `router.replace`, never `push`, so the back button cannot loop.
// The URL is only judged after the list loaded, otherwise every deep link would look invalid.
// `paused` lets the screen finish its own navigation (after a delete) without a competing redirect.
export const useMasterDetailRedirect = ({
  items,
  loaded,
  selectedId,
  atIndex,
  isMobile,
  paused,
  detailLocation,
  indexLocation,
}) => {
  const router = useRouter();
  watch(
    [loaded, items, selectedId, atIndex, isMobile],
    () => {
      if (!loaded.value || paused.value) return;
      const target = resolveSelection({
        items: items.value,
        selectedId: selectedId.value,
        atIndex: atIndex.value,
        isMobile: isMobile.value,
      });
      if (!target) return;
      router.replace(target.id ? detailLocation(target.id) : indexLocation());
    },
    { immediate: true }
  );
};
```

### `useUnsavedChangesGuard.js`

```js
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router';
import { useEventListener } from '@vueuse/core';

// Asks before leaving with pending edits. Switching items keeps the same route record (only the id
// changes), so the update guard is what protects a click on another item in the list.
// `dialogRef` is a template ref to an UnsavedChangesDialog.
export const useUnsavedChangesGuard = (isDirty, dialogRef) => {
  const confirmLeave = () => (isDirty.value ? dialogRef.value.ask() : true);
  onBeforeRouteLeave(confirmLeave);
  onBeforeRouteUpdate(confirmLeave);
  useEventListener(window, 'beforeunload', event => {
    if (!isDirty.value) return;
    event.preventDefault();
    Object.assign(event, { returnValue: '' });
  });
};
```

### `EmptyRoute.js`

```js
// Route component for the index of a master-detail screen: the screen decides what to show
// (loading, empty state or the item it redirects to), so the router has nothing to render.
export default { name: 'EmptyRoute', render: () => null };
```

### `UnsavedChangesDialog.vue`

```vue
<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const dialogRef = ref(null);
let answer = null;

const resolveAnswer = value => {
  answer?.(value);
  answer = null;
};

// Resolves `true` when the person chooses to leave and `false` when they keep editing.
const ask = () => {
  resolveAnswer(false);
  return new Promise(resolve => {
    answer = resolve;
    dialogRef.value?.open();
  });
};

const confirmLeave = () => {
  resolveAnswer(true);
  dialogRef.value?.close();
};

defineExpose({ ask });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="t('AI_HUB.UNSAVED_TITLE')"
    :description="t('AI_HUB.UNSAVED_CONFIRM')"
    :confirm-button-label="t('AI_HUB.UNSAVED_LEAVE')"
    :cancel-button-label="t('AI_HUB.UNSAVED_STAY')"
    @confirm="confirmLeave"
    @close="resolveAnswer(false)"
  />
</template>
```

### `DetailState.vue`

```vue
<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

// Empty and error states of the detail panel.
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  actionLabel: { type: String, default: '' },
  actionIcon: { type: String, default: '' },
  isError: { type: Boolean, default: false },
});

defineEmits(['action']);
</script>

<template>
  <div class="flex flex-col items-start gap-4 p-6">
    <div
      class="flex flex-col items-start gap-4 w-full max-w-xl p-6 border border-dashed rounded-xl border-n-weak"
      :role="isError ? 'alert' : undefined"
    >
      <div>
        <p
          class="font-medium"
          :class="isError ? 'text-n-ruby-9' : 'text-n-slate-12'"
        >
          {{ title }}
        </p>
        <p v-if="description" class="mt-1 text-sm text-n-slate-11">
          {{ description }}
        </p>
      </div>
      <Button
        v-if="actionLabel"
        :label="actionLabel"
        :icon="actionIcon"
        @click="$emit('action')"
      />
    </div>
  </div>
</template>
```

### `DetailSkeleton.vue`

```vue
<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <div
    role="status"
    :aria-label="t('AI_HUB.LOADING')"
    class="flex flex-col gap-6 p-6 animate-pulse"
  >
    <div class="flex items-center gap-3">
      <div class="h-7 rounded-lg w-52 bg-n-alpha-2" />
      <div class="w-20 h-5 rounded-full bg-n-alpha-2" />
    </div>
    <div class="h-10 rounded-xl bg-n-alpha-1" />
    <div class="flex flex-col gap-4 p-5 rounded-xl bg-n-solid-2">
      <div class="w-40 h-5 rounded-md bg-n-alpha-2" />
      <div class="h-10 rounded-lg bg-n-alpha-2" />
      <div class="h-10 rounded-lg bg-n-alpha-2" />
      <div class="h-24 rounded-lg bg-n-alpha-2" />
    </div>
  </div>
</template>
```

### `ListSkeleton.vue`

```vue
<template>
  <div class="flex flex-col gap-2 p-3 animate-pulse" aria-hidden="true">
    <div
      v-for="index in 4"
      :key="index"
      class="flex flex-col gap-2 p-3 rounded-xl bg-n-alpha-1"
    >
      <div class="w-3/4 h-4 rounded-md bg-n-alpha-2" />
      <div class="w-1/2 h-3 rounded-md bg-n-alpha-2" />
    </div>
  </div>
</template>
```

### `CollapsibleSection.vue`

```vue
<script setup>
import { ref } from 'vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  defaultOpen: { type: Boolean, default: true },
  // Render the content only once the section is opened for the first time.
  lazy: { type: Boolean, default: false },
});

const open = ref(props.defaultOpen);
const rendered = ref(props.defaultOpen || !props.lazy);

const toggle = () => {
  open.value = !open.value;
  if (open.value) rendered.value = true;
};
</script>

<template>
  <section class="rounded-xl bg-n-solid-2">
    <button
      type="button"
      class="flex items-center justify-between w-full gap-3 p-5 text-start"
      :aria-expanded="open"
      @click="toggle"
    >
      <span class="min-w-0">
        <span class="block font-medium text-n-slate-12">{{ title }}</span>
        <span v-if="description" class="block mt-1 text-sm text-n-slate-11">{{
          description
        }}</span>
      </span>
      <span
        class="i-lucide-chevron-down size-4 shrink-0 text-n-slate-11 transition-transform"
        :class="{ 'rotate-180': open }"
        aria-hidden="true"
      />
    </button>
    <div v-if="rendered" v-show="open" class="flex flex-col gap-5 px-5 pb-5">
      <slot />
    </div>
  </section>
</template>
```

### `CopyIdButton.vue`

```vue
<script setup>
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  id: { type: [String, Number], required: true },
});

const { t } = useI18n();

const copy = async () => {
  try {
    await copyTextToClipboard(props.id);
    useAlert(t('AI_HUB.ID_COPIED'));
  } catch {
    useAlert(t('AI_HUB.ID_COPY_ERROR'));
  }
};
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-1.5 px-2 py-1 font-mono text-xs rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
    :aria-label="t('AI_HUB.COPY_ID')"
    @click="copy"
  >
    <span>{{ t('AI_HUB.ID') }} {{ id }}</span>
    <span class="i-lucide-copy size-3.5" aria-hidden="true" />
  </button>
</template>
```
