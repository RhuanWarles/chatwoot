# SaaS AI and voice usage

The account-scoped page at `/app/accounts/:accountId/settings/ai-voice` now displays balances and existing usage history only.
Agent configuration lives in the [AI Agents hub](ai-agents-hub.md), including the existing encrypted account text credentials.
The APIs and legacy voice services documented below remain intact, but draft-generation and start-call actions are no longer exposed on the usage page.
New voice-agent records are configuration only and are not connected to these legacy calling services.
It is independent of Captain and its enterprise billing. It does not change existing Captain/WhatsApp automations.
Only account administrators can configure the module, generate drafts or start calls. Drafts are not sent to contacts.

## Configure the platform

Run `bundle exec rails db:migrate`. Configure the existing `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
before accepting customer API keys. Secrets are encrypted by Active Record, omitted from responses, and filtered from request logs.
Back up encryption keys separately from the database. Losing them makes saved customer keys unreadable.

Text uses the existing RubyLLM dependency and a separate configuration context for every request:

```dotenv
SAAS_TEXT_PROVIDER=openai
SAAS_TEXT_MODEL=your-supported-model-id
SAAS_TEXT_API_KEY=your-platform-provider-key
SAAS_TEXT_CREDITS_PER_REQUEST=1
```

Supported providers: `openai`, `anthropic`, `gemini`. Platform models and keys are operator-controlled.
Customers can instead choose their provider/model and save their own key. BYOK does not debit platform text credits,
and there is no automatic fallback to the platform key. A draft has at most 8,000 input characters and 1,024 output tokens.
Run Sidekiq for text generation and outbound calling. No money prices or checkout are defined by this module.

```dotenv
VAPI_PRIVATE_KEY=your-platform-private-key
VAPI_WEBHOOK_SECRET=a-long-random-secret
VAPI_WEBHOOK_URL=https://your-public-host/webhooks/vapi
```

The Vapi private key is never configurable by tenant APIs. Create a dedicated assistant and phone number per tenant
in your platform Vapi organization. Configure the assistant's language, model, voice, recording policy and summary there.
Do not attach phone-number-level workflows/squads that bypass assistant-request admission. Do not place calls outside this module
if they are expected to use the tenant wallet.

Connect an existing platform-owned number (this updates its Vapi server URL and removes its fixed assistant):

```sh
bundle exec rake 'saas:connect_voice[1,ASSISTANT_UUID,PHONE_NUMBER_UUID]'
```

The HTTPS endpoint must be reachable from Vapi. Localhost alone cannot receive provider webhooks.
Incoming `assistant-request` events are matched to the tenant by the assigned phone number ID. The module reserves
available time and returns the assistant plus `maxDurationSeconds`; insufficient balance or disabled inbound calling rejects admission.
Vapi expects this response within 7.5 seconds, so validate latency from the deployment region.
Outgoing calls use the same reservation path and pass the duration limit to Vapi.
Both paths explicitly configure the webhook Authorization header, including for request-supplied assistant overrides.

## Add balance

Only trusted server-side provisioning/billing code may grant balance. There is deliberately no tenant top-up API.
One voice unit is one second; 600 units is 10 minutes. All balances start at zero.

```sh
bundle exec rake 'saas:credit[1,voice_seconds,600,trial-voice-account-1]'
bundle exec rake 'saas:credit[1,text_credits,20,trial-text-account-1]'
```

Use a unique payment/grant reference. Repeating the same grant does not add balance again;
reusing its reference with a different amount is rejected. A future billing integration must call `Saas::Wallet#credit!`
only after validating the payment server-side.

Text AI Agents use the same `text_credits` wallet. In platform mode, a response reserves the configured
`SAAS_TEXT_CREDITS_PER_REQUEST` amount before calling the provider and settles it only after the outgoing message
is persisted. Provider failures and stale responses release the reservation. Agent reservations expire after 15 minutes;
run `bundle exec rake saas:reconcile_ai_agent_credits` from the platform scheduler to release reservations left by a
worker crash. The expiration is longer than the provider request timeout and retry window, so an active request is not
released while it is still running. BYOK agent responses do not create usage records or consume platform credits.

The wallet serializes reservations and settlement under a row lock. Concurrent calls cannot reserve the same seconds.
At call end, connected duration is rounded up to the next second and capped at the authorized maximum. Unused time is released.
There is no per-call rounding to a full minute. Replayed reports do not charge again. A call without a connected start consumes zero seconds.
The customer-facing connected-time policy is distinct from the supplier's invoice; reconcile supplier costs separately.
Changing settings affects new admissions, not reservations already made.

## Reconciliation and limitations

Definite outbound HTTP rejection releases the reservation. A timeout or server error may have started a real call;
the module keeps its reservation, marks it `unknown`, and never redials automatically. Use Vapi metadata `saas_call_id`
to locate it in the provider dashboard. If the create response was lost, the signed event can attach the provider call ID.
For missing completion webhooks where the provider ID is known, run:

```sh
bundle exec rake 'saas:reconcile_voice[1]'
```

Investigate requests without a provider ID before any manual release. Also investigate text jobs stuck in `running`
after a worker crash; do not automatically rerun billable provider operations.
The first version supports explicit outgoing calls and inbound reception, not outbound campaigns, payment checkout,
automatic replenishment, expiry of monthly allowances or autonomous WhatsApp replies.
The call history includes contact linkage where the phone number matches, summary, status and per-call debit.
Transcripts are kept server-side. No recordings are downloaded.

Before production, run a real inbound and outbound call with the platform credentials and public HTTPS webhook,
confirm the configured assistant obeys its duration limit, and measure local-language call quality.

References: https://docs.vapi.ai/server-url/events,
https://docs.vapi.ai/server-url/server-authentication,
https://docs.vapi.ai/api-reference/calls/create,
https://rubyllm.com/configuration/.
