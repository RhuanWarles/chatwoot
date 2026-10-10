# Controle de IA por Account no Super Admin

## Configuração e compatibilidade

A gestão continua em `/super_admin/accounts/:id/saas_usage`. Há controles independentes de Text AI e Voice AI, status nos cards de saldo e confirmação antes de desabilitar uma modalidade com agentes ativos. As carteiras continuam visíveis ao Super Admin mesmo com o recurso desabilitado.

Reutilizamos as features persistidas da Account: `text_ai` e `voice_ai`, nos slots 11 e 12 de `feature_flags_ext_1`. Não há novas tabelas ou colunas. A migration `20261010020000_enable_existing_account_ai_features.rb` habilita ambos os recursos nas Accounts existentes, preservando os outros bits. Novas Accounts também começam com ambos habilitados, mantendo o comportamento anterior.

Somente o Super Admin pode mudar esses acessos, pela ação `saas_features`. A edição geral de features preserva os dois valores; a API Platform rejeita tentativas de alterá-los. `Saas::AdminAiFeatures` registra Account, modalidade, valor anterior/novo, responsável e data em `internal_attributes['ai_feature_history']`, exibido na mesma tela. Agentes, configurações, saldo e histórico de consumo permanecem armazenados.

## Ajustes manuais de saldo

O seletor Operation foi removido. O formulário aceita inteiros com sinal: `100` adiciona, `-100` remove e `0` é inválido. O motivo continua obrigatório. Voice usa minutos no formulário e segundos na persistência: `-10` remove 600 segundos.

`Saas::AdminCreditAdjustment` utiliza `Wallet#credit!` e `Wallet#debit!`, mantendo os registros de uso e a idempotência. O débito valida o saldo disponível dentro do lock da carteira e considera reservas pendentes. Não há escrita direta de `balance_units` nem possibilidade de pós-pago. Os metadados incluem quantidade original com sinal, recurso, motivo e responsável; a referência identifica a operação.

## Bloqueios de acesso

O frontend recebe as features pelo store existente da Account. A sidebar mostra AI Agents se ao menos uma modalidade estiver disponível. O hub filtra as abas, normaliza a query string para uma modalidade permitida e não monta o componente proibido. Sem ambas, mostra recurso indisponível. Os componentes recalculam o acesso na troca de Account e descartam respostas de outra Account.

O backend retorna 403 nos endpoints específicos de agentes de texto/voz, gerações de texto e chamadas de voz. O endpoint compartilhado SaaS AI filtra configurações, carteiras, chamadas e uso pela modalidade permitida; updates de campos proibidos são rejeitados antes de salvar. Os webhooks de entrada de voz também respeitam o bloqueio.

O runtime de agentes de texto, TextService e VoiceService validam a feature antes de reservar saldo ou chamar o provider. Jobs já enfileirados liberam as reservas quando a modalidade foi desabilitada. A liquidação de chamadas previamente autorizadas continua preservada. Desabilitar acesso não modifica `agent.active`; reabilitar restaura a disponibilidade sem recriar agentes.

## Arquivos de implementação

- Modelagem: `config/features.yml`, `app/models/account.rb`, `app/models/concerns/saas/account_ai_access.rb`, `db/migrate/20261010020000_enable_existing_account_ai_features.rb`.
- Administração: `app/controllers/super_admin/accounts_controller.rb`, `app/helpers/super_admin/account_features_helper.rb`, `app/services/saas/admin_ai_features.rb`, `app/services/saas/admin_credit_adjustment.rb`, as views `saas_usage.html.erb` e `saas_feature_confirmation.html.erb`, `config/routes.rb`, `config/locales/en.yml`.
- APIs: `app/controllers/concerns/saas_ai_access.rb`, os controllers account-scoped `ai_agents_controller.rb`, `voice_agents_controller.rb`, `saas_ai_controller.rb`, `app/controllers/platform/api/v1/accounts_controller.rb`, `app/controllers/webhooks/vapi_controller.rb`.
- Runtime: `app/services/saas/ai_agents/runtime.rb`, `app/services/saas/text_service.rb`, `app/services/saas/voice_service.rb`, `app/jobs/saas/start_voice_call_job.rb`.
- Frontend: `Sidebar.vue`, `settings/aiAgents/Index.vue`, `settings/saasAI/Index.vue`, `app/javascript/dashboard/i18n/locale/en/en.json`.
- Build incremental: `docker/Dockerfile.incremental` inclui a nova migration; nenhuma stack foi criada ou alterada.

## Validação

Os testes cobrem ajustes 400 + 100 e 400 - 100, reservas que impedem remover 351 de 350 disponíveis, zero inválido, conversão de minutos, auditoria e idempotência. Cobrem também as quatro combinações de acesso, APIs proibidas, confirmação, preservação e reativação de agentes/saldos, jobs enfileirados, migração e permissões do Super Admin/Account/Platform API.

Os testes do hub cobrem abas, query string direta e troca de Account na SPA. O frontend passou em 14 testes, ESLint sem erros (dois avisos de i18n da sidebar) e build de produção com Node 24. A validação do backend usa PostgreSQL/Redis locais isolados, sem dados de produção. O RuboCop ainda aponta limites de complexidade/tamanho em arquivos existentes; não foram feitas refatorações fora do escopo para eliminá-los. Não foi realizada validação visual em navegador.

Esta implementação está somente no workspace: sem commit, push ou deploy.
