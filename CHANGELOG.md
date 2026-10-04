# Changelog do CRM

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
