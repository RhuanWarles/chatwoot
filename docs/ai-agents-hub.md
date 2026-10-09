# Hub AI Agents

O menu principal tem um único item **AI Agents**, com abas Texto e Voz. O link **Uso de IA** abre os saldos, minutos, histórico de chamadas já existente e registros de uso.

## Navegação

- Texto: `/app/accounts/:accountId/settings/ai-agents?type=text`.
- Voz: `/app/accounts/:accountId/settings/ai-agents?type=voice`.
- Links antigos para `/settings/ai-agents` continuam abrindo Texto.
- A aba é determinada pela URL e permanece ao atualizar a página.
- A antiga rota `/app/accounts/:accountId/settings/ai-voice` permanece válida como Uso de IA.

## Texto

O componente existente foi movido para `TextAgents.vue`, sem recriar o CRUD, registros ou vínculos com inboxes. Provider, modelo, temperatura, prompt, ativação, transferência e opção de responder em grupos continuam usando `Saas::AiAgent` e `/api/v1/accounts/:account_id/ai_agents`.

A seção recolhível **Conexão do provedor de texto** reutiliza `/api/v1/accounts/:account_id/saas_ai`. As credenciais continuam criptografadas em `Saas::AiSetting`, vinculadas à conta. A resposta não devolve a chave salva. Salvar os campos de texto não envia nem sobrescreve opções de voz da configuração antiga; deixar a chave em branco preserva a existente, salvo a regra atual de troca de provider.

Não há migração ou alteração dos agentes existentes, como a Larissa, nem mudança no runtime de respostas.

## Voz

`Saas::VoiceAgent` usa a tabela `saas_voice_agents`, separada dos agentes de texto e das configurações legadas de chamadas. Campos:

- `account_id`, `name`, `description`, `provider`;
- `active`, `assistant_id`, `phone_number_id`;
- `inbound_enabled`, `outbound_enabled`, `max_call_duration`;
- `created_at`, `updated_at`.

`max_call_duration` é opcional, em segundos, com o intervalo existente de 10 a 3600. Novos registros são inativos e não habilitam inbound/outbound automaticamente. Identificadores do provider podem ficar vazios durante o cadastro.

API: `GET/POST /api/v1/accounts/:account_id/voice_agents` e `GET/PATCH/DELETE /api/v1/accounts/:account_id/voice_agents/:id`, com payload `{ "voice_agent": { ... } }`. A listagem fornece os providers e limites aceitos pela interface. Inicialmente o provider permitido é `vapi`; outros podem ser adicionados sem mudar o contrato de cadastro.

Todas as operações exigem administrador e consultam a associação da conta atual. Tipos inválidos, secrets e tentativa de definir `account_id` no payload são rejeitados.

**Esta etapa só cadastra configuração.** Ativar um agente de voz não realiza, recebe ou agenda chamadas. Não há ligação entre esse novo cadastro e o runtime legado, nem novas integrações, webhooks ou cobrança.

## Uso de IA

Preserva carteiras, reservas, créditos, minutos, histórico de chamadas e uso existentes. Configuração e botões de gerar texto/iniciar chamada foram retirados dessa tela. Models e endpoints anteriores permanecem disponíveis; nenhuma informação histórica foi apagada.

## Validação

Os testes cobrem CRUD de voz, ativação/desativação, ausência de criação de chamadas, preservação de texto, isolamento por conta, permissões administrativas, tipos inválidos, limites de duração e rejeição de secrets. Na interface, cobrem a aba na URL/refresh, salvamento de credenciais sem sobrescrever configurações de voz e preservação do formulário quando ocorre erro.

Validação em 09/10/2026: 37 exemplos de regressão de texto, 7 exemplos da API de voz e 9 testes de interface aprovados. A migração foi executada no PostgreSQL local isolado. RuboCop dos novos arquivos Ruby passou sem infrações; ESLint passou sem erros (avisos de estilo/i18n permanecem); os cinco componentes Vue foram compilados. Não foi realizado teste manual em navegador nem build completo de produção.

Para instalar a alteração é necessário executar a migração `20261009230000_create_saas_voice_agents`. Nenhum push, deploy remoto ou alteração de stack faz parte desta entrega.

## Arquivos da alteração

- Navegação: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`, `app/javascript/dashboard/routes/dashboard/settings/aiAgents/Index.vue`, `aiAgents.routes.js`.
- Texto e credenciais: `app/javascript/dashboard/routes/dashboard/settings/aiAgents/TextAgents.vue`, `TextCredentials.vue`.
- Voz: `app/javascript/dashboard/routes/dashboard/settings/aiAgents/VoiceAgents.vue`, `voiceForm.js`, `app/javascript/dashboard/api/voiceAgents.js`.
- Uso: `app/javascript/dashboard/routes/dashboard/settings/saasAI/Index.vue`.
- Backend: `app/models/account.rb`, `app/models/saas/voice_agent.rb`, `app/controllers/api/v1/accounts/voice_agents_controller.rb`, `config/routes.rb`.
- Migração: `db/migrate/20261009230000_create_saas_voice_agents.rb`.
- Traduções: `app/javascript/dashboard/i18n/locale/en/en.json` (somente o idioma fonte, conforme as instruções do projeto).
- Testes: `spec/requests/api/v1/accounts/voice_agents_spec.rb`, `app/javascript/dashboard/routes/dashboard/settings/aiAgents/specs/voiceForm.spec.js`, `hub.spec.js`.
- Documentação: `README_INSTALACAO.md`, `docs/ai-agents-hub.md`, `docs/ai-agents.md`, `docs/ai-agent-runtime.md`, `docs/saas-ai-voice.md`.
