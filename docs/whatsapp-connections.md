# Optional WhatsApp connection management

The WhatsApp module manages Evolution connections from the Chatwoot dashboard. It does not replace the existing API-inbox message adapter or create native `Channel::Whatsapp` inboxes.

## Enablement and permissions

Configure both `EVOLUTION_API_URL` and `EVOLUTION_API_KEY` in the Rails environment. The URL can point to the same stack, another Compose project, or an external VPS/domain. The module does not assume an `evolution` Docker hostname.

`Evolution::Configuration.available?` checks both values. Rails exposes only the boolean `WHATSAPP_CONNECTIONS_ENABLED` in the dashboard configuration. The key and provider URL are not included in that configuration or connection JSON. All provider requests originate in Rails, with redirects disabled so the credential cannot be forwarded to another host.

When either setting is absent, the sidebar entry and routes are absent, inbox integration controls are hidden, and the connection API returns 404 before invoking any provider client. Migrations, model associations and ordinary inbox operations do not require Evolution.

Management is administrator-only, using existing account authentication/authorization. Every local connection and inbox is resolved through `Current.account`; callers cannot choose a technical instance name. Instances use `account-{account_id}-{random_16_hex_characters}`. No provider-wide list is exposed to the browser.

## Existing inbox adapter

The existing setting remains `Channel::Api.additional_attributes['evolution_instance_name']`. Linking writes this setting and the configured provider's `/chatwoot/webhook/{instance_name}` URL to the existing API channel. Other channel attributes are preserved.

The custom Evolution adapter correlates the inbox by **account ID and inbox name**, not an inbox ID. Binding therefore rejects ambiguous duplicate inbox names. Each managed connection can have one inbox; each inbox can have one managed connection. To replace an already-managed inbox connection, first unlink it from its current connection's management screen. The QR session itself is not logged out by unlinking.

The provider's `chatwoot/set` configuration uses the existing public `FRONTEND_URL`, the current administrator's Chatwoot API token (server-side only), the account ID and the chosen inbox name. It uses `autoCreate: false`, so it does not create or delete inboxes. The Evolution installation must already have its Chatwoot integration enabled. The configured Chatwoot URL must be reachable from Evolution, and API access must remain permitted by the existing account policies. Revoking the administrator's API token requires explicitly relinking using a valid administrator.

New provider configurations do not import contacts or message history automatically. Existing adapter options, including message signing, are retained when relinking.

The inbox select lists account-local connections, retains an unmatched manual setting as an explicit legacy option, and does not rewrite it on page load. Selecting and saving a different managed connection is an explicit replacement, with a warning that the previous manual instance name/webhook will be replaced. Existing manually configured instances are not imported, renamed or deleted automatically.

Unlinking/deleting clears the channel instance setting only if it still points at that connection. The webhook is cleared only if it also matches that connection's configured webhook. Inbox records, conversations and other settings are never deleted by this module. Both the list and detail screens require the design-system confirmation dialog before deleting a connection.

## Lifecycle and failures

Creation persists the local record first, creates the provider instance, optionally configures its inbox, and initiates pairing. The display name is independent of the technical name.

Opening management refreshes provider state and profile information. States map as follows: `open` → `connected`, `connecting` → `connecting`, `close` → `disconnected`, `refused` or an unknown state → `error`.

While pairing, the browser polls the account-scoped Rails show endpoint every three seconds, without overlapping requests. Polling stops on connected/disconnected/error, navigation or disposal. Scanning and connecting removes the QR from the view and refreshes number/profile data. The QR is transient and is never stored in the database.

The provider does not return an authoritative QR expiration timestamp. The UI therefore limits the display of an unchanged QR to 60 seconds, preserving its age across polling responses. A changed QR resets this display window. Regeneration uses the verified restart endpoint only while connecting; an already-open connection is never restarted by a stale QR-regeneration action.

Each provider request has a five-second connection timeout and a ten-second read timeout. Timeouts, failed HTTP responses, malformed successful payloads and HTTP-200 responses carrying `error: true` return a normalized Rails error (`evolution_unavailable`) instead of an unhandled exception. A failed live status/profile query preserves the last persisted status and the UI shows a temporary `Provider unavailable` badge. Failed remote deletion retains the local record and inbox association. An explicit remote 404 during deletion permits local cleanup. If instance creation has an uncertain result, the local record remains visible with an error; the application does not automatically repeat creation. Inspect/reconnect or explicitly delete the failed connection before starting a new one.

Database transactions/row locks protect local association changes and serialize competing inbox claims. They are not distributed transactions with Evolution: a provider timeout can leave an uncertain remote configuration, which should be checked before retrying. Deleting an account or inbox uses local associations only; it does not invoke the provider from model callbacks. Explicitly delete connections through the management API when remote instance removal is required.

## Verified provider endpoints

Audited from the custom Evolution repository at `d060264e3aaa30d1e5c6e8e44ce518597eb5f479` (`v1.0.2`): `src/api/routes/instance.router.ts`, `src/api/controllers/instance.controller.ts`, and the Chatwoot router/controller/service plus `src/api/services/channel.service.ts`.

| Operation | Provider endpoint |
| --- | --- |
| Create | `POST /instance/create` |
| Connect/current QR | `GET /instance/connect/{instance_name}` |
| Connection state | `GET /instance/connectionState/{instance_name}` |
| Scoped profile | `GET /instance/fetchInstances?instanceName={instance_name}` |
| Restart pairing | `POST /instance/restart/{instance_name}` |
| Logout | `DELETE /instance/logout/{instance_name}` |
| Delete | `DELETE /instance/delete/{instance_name}` |
| Read adapter options | `GET /chatwoot/find/{instance_name}` |
| Configure adapter | `POST /chatwoot/set/{instance_name}` |

## Rails API

All paths start with `/api/v1/accounts/{account_id}/whatsapp_connections`:

- `GET /`: local connections and API inbox choices, without provider-wide enumeration.
- `POST /`: `{ "display_name": "Commercial", "inbox_id": 123 }`; `inbox_id` is optional/null and must otherwise be a positive JSON integer.
- `GET /{id}`: live status/profile and the current PNG QR while pairing.
- `PATCH /{id}`: update `display_name` and/or `inbox_id`; explicit null unlinks the inbox.
- `POST /{id}/connect`: optional boolean `regenerate` (default false).
- `POST /{id}/disconnect`: disconnect without deleting or unlinking.
- `DELETE /{id}`: delete provider instance and local record, preserving the inbox.

Migration: `20261020180000_create_whatsapp_connections.rb`. It creates only a new table, with account/inbox references, unique technical name and unique nullable inbox mapping. It does not backfill or rewrite legacy inbox settings.

Tests mock all Evolution calls using WebMock/Vitest; no real pairing, messages, reactions or provider instance mutations are performed by the test suite.
