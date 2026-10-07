# Changelog do CRM

## v1.0.10 — preparada para publicação

- Menções reais de participantes de grupo: identidade estruturada no composer,
  rascunhos e `content_attributes.whatsapp_mentions`, com validação por grupo/account.
- Renderização de LID/JID como nome humano, incluindo mensagens antigas, com
  prioridade para Contact salvo e sem alterar o conteúdo original persistido.
- Metadados e intervalos Unicode preservam a identidade de pessoas com nomes iguais.
- Stack passa a expor as variáveis de runtime da integração Evolution no Web/worker;
  a chave permanece no backend e não entra nos atributos públicos da Inbox.
- Inclui o patch do adaptador nativo da Evolution 2.3.7 em `deploy/evolution/`.
  A imagem oficial da Evolution sem esse patch não envia a metadata de menção.
- Não altera a implantação atual da VPS. Evolution continua como serviço externo.

## v1.0.0 — preparada, ainda não publicada

### CRM

- Pipelines e etapas configuráveis; novos pipelines com cinco etapas editáveis.
- Kanban de negócios, drag and drop, navegação horizontal e status Em andamento/Ganho/Perdido.
- Filtros rápidos/avançados, busca de negócios e integração com busca global.
- Página de detalhes do Deal e edição inline dos dados nativos e Custom Fields.
- Troca inline de Pipeline com primeira etapa por position e auditoria de Pipeline/Etapa.
- Activities, próximas atividades, conclusão e cancelamento com motivo estruturado.
- Indicador da próxima atividade nos cards do Kanban.
- Timeline/histórico, anotações e acesso às Conversations nativas do contato.
- Sidebar principal recolhível.
- Integração pessoal com Google Calendar/Meet, condicionada à configuração OAuth e sincronização.

### Empacotamento

- Uma imagem customizada para Web e Sidekiq, assets de produção e lockfile frontend respeitado.
- Workflow GHCR para tags semânticas, incluindo v1.0.0 e tag pelo SHA do commit.
- Stacks independentes para Portainer Docker Standalone: dependências internas ou PostgreSQL/Redis externos.
- Volumes persistentes, healthchecks e preparação do banco em operação separada.
- Guia de release, atualização, rollback e segredos.

### Limites

- IA não foi implementada ou alterada nesta release; módulos já existentes são opcionais e independentes.
- A conversa é aberta pela interface nativa do Chatwoot; não existe um sistema paralelo de mensagens no CRM.
- Cancelar convite/reunião depende de sincronização com o Google; salvar Activity local não confirma evento remoto.
- A publicação v1.0.0 só deve ser anunciada após build completo, validação em ambiente isolado e criação autorizada da tag.
