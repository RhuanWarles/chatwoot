# Text AI agents

Administrators can manage agents in **Settings → AI Agents** (`/app/accounts/:accountId/settings/ai-agents`). The list shows name, active state, provider, model, inboxes and last update. The editor uses the existing Chatwoot Input, ComboBox, Button and Dialog components, with a large multiline prompt, inbox checkboxes and a handoff preference. Empty states, errors, retry and delete confirmation are included. Styling uses theme-aware Tailwind utilities.

Active agents can now reply to public text messages in their selected inboxes using the account's own OpenAI key. Group replies require explicit opt-in. Native message delivery, conversation history and human takeover are preserved. See [runtime configuration and limits](ai-agent-runtime.md). Platform credits, other providers, voice AI and CRM tools are outside this runtime.

## Data and API

- Migration: `20261004170000_create_saas_ai_agents.rb`, compatible with `db:chatwoot_prepare`.
- `Saas::AiAgent` belongs to Account; Account has many agents, removed on account deletion.
- `Saas::AiAgentInbox` connects agents and native Inbox, with a unique `(ai_agent_id, inbox_id)` index. Deleting either side removes links through Rails associations.
- REST: `GET/POST /api/v1/accounts/:account_id/ai_agents`; `GET/PATCH/DELETE /api/v1/accounts/:account_id/ai_agents/:id`.
- Index returns `agents`, `providers` and `temperature_range`. Each agent includes its configuration, account ID, timestamps and linked inbox IDs/names. Show includes the prompt for editing. No secret fields are accepted or serialized.
- Existing account authentication and administrator authorization apply to every endpoint. Cross-account agent IDs produce 404; foreign inbox IDs and malformed configuration produce 422.

## Reuse and decisions

The project already has RubyLLM in `Saas::TextService`, encrypted credentials in `Saas::AiSetting`, and Enterprise Captain assistants. New agents reuse `Saas::AiSetting::PROVIDERS` (OpenAI, Anthropic, Gemini). Model is a required free-text identifier, not a hardcoded catalog. Additional providers require a deliberate extension of the existing provider layer when runtime is implemented. No second provider client, key store or Captain message handler is introduced.

Temperature is numeric, finite and within 0–1, default 0.7. This conservative configuration range is not a claim that every future provider/model accepts temperature; runtime must honor the selected model's capabilities. Agents default inactive; handoff preference defaults true but has no behavior yet. Names/model identifiers are limited to 100 characters; prompts use a text column and retain newlines without an application truncation limit.

An inbox may link to multiple inactive configurations, but at most one active text agent. API writes go through `configure!`, which locks the Account row inside a transaction before changing fields, inbox links and active state. This serializes competing activations and rolls back links if validation fails. Future callers must use this same entry point. The UI shows occupied inboxes; backend validation remains authoritative. Existing Captain/bot assignments are independent and unchanged; any future runtime must resolve coexistence before dispatching messages.

Translations are added to source `en.json` only, following the repository's Crowdin workflow. No strings are hardcoded in Vue templates. Other locale translations remain a localization step.

## Verification

Request/model specs cover CRUD, default inactivity, prompt preservation, inbox linkage/removal, tenant isolation, foreign inbox rejection, admin authorization, activation conflicts and strict field types. Frontend specs cover draft defaults, required values, temperature and safe payload creation. There are no runtime LLM or messaging tests because those paths are intentionally absent.

Do not publish or deploy this phase until its migration and configuration flow have been validated in the target test environment. Existing provider credentials are neither changed nor copied to agents.

Validation on 2026-10-04: the three frontend tests passed in Vitest 3.0.5; Vue script/template compilation passed; ESLint reported zero errors (style/i18n warnings remain); Ruby syntax checks passed for the migration, models, controller and specs. The Rails specs could not execute because the local WSL bundle is missing the project's gems, including RSpec. No migrations or functional browser tests were executed. No application server was started locally and production was not accessed.

To complete backend verification in a configured development/test environment (never a production database): initialize rbenv, install the project's locked bundle, prepare an isolated test database, then run `bundle exec rspec spec/models/saas/ai_agent_spec.rb spec/requests/api/v1/accounts/ai_agents_spec.rb`. The full login/configuration flow and concurrent activation requests still need runtime validation.
