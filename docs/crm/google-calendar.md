# CRM Google Calendar and Meet

Each account member connects their own Google account. Credentials are encrypted with the installation's existing Active Record Encryption keys. A member cannot use another member's Google credentials. Administrators can find the personal integration under Settings > Integrations. Agents can open their personal integration through the link in the Deal meeting form.

## Installation setup

1. In Google Cloud, enable Google Calendar API and configure the OAuth consent screen. If the application is in Testing mode, register the people who will connect as test users. A service-account JSON/private key is not an OAuth Web client.
2. Create an OAuth client of type **Web application**. Register this exact redirect URI for this installation:
   `https://chatwoot.rwhub.com.br/crm/google_calendar/callback`
   Register the application's origin `https://chatwoot.rwhub.com.br` if using the same client for the existing Google sign-in feature. Retain any redirect URIs required by the installation's existing Google integrations.
3. Set the existing installation settings `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET` through Super Admin application configuration. Do not paste tokens or service-account credentials into these fields. The integration uses `GlobalConfigService` and `GoogleConcern`, consistent with the existing Google OAuth integration. Installation settings take precedence over environment variables.
4. Ensure the existing Active Record Encryption keys remain configured and backed up. Do not rotate those keys as part of this setup.
5. Open Settings > Integrations > Google Calendar and connect your personal Google account.

Requested scopes: `openid`, `email`, and `https://www.googleapis.com/auth/calendar.events.owned`. Identity scopes prevent an event from being accidentally synchronized into a different Google account after reconnecting. Events are created in the connected account's primary calendar. This implementation does not use the PitchYes service account or its fixed company calendar.

## Meetings

Create or edit an activity of type Meeting. Set date, time, duration and participants. The Deal contact's email is prefilled when available. Select Create event in Google Calendar and optionally Create Google Meet link. The responsible user must be the connected user. Participants receive Google's invitations and subsequent updates.

The local activity is saved first. A background job synchronizes the event using a stable preallocated Google event ID. Edits update the same event. Meet generation may be asynchronous; the UI shows pending until the link is available. Confirm scheduling with the Synced status and Open in Google Calendar link. An invitation being sent does not mean the participants have accepted it.

Cancellation updates the local activity and removes the external event with participant notifications. Failed cancellation remains visible with an error and retry action. Retries retain the same event ID. Cancelled activities with failed synchronization remain visible until the external cancellation succeeds.

Disconnecting removes local credentials and attempts Google token revocation, preserving CRM activities and history. If Google cannot confirm revocation, the UI instructs the user to remove the app in Google Account permissions. Reconnect the original Google account to resume synchronization of existing meetings. A different Google identity cannot edit the old calendar's events.

## Verification

Frontend tests cover local and Google meetings, contact participants, owner restrictions, Meet/event links, failed synchronization retry and connection states. API verification uses simulated Google HTTP responses to exercise OAuth cancellation, browser-bound state and PKCE, encrypted credentials, token refresh, creation, editing without duplication, Meet generation/polling, cancellation, failure, retry, reconnect and account/user isolation. Real Google authorization and invitations require an OAuth Web client configured for this installation and a user completing consent.

Provider references: [OAuth web applications](https://developers.google.com/identity/protocols/oauth2/web-server), [Calendar scopes](https://developers.google.com/workspace/calendar/api/auth), [Create events and Meet](https://developers.google.com/workspace/calendar/api/guides/create-events).
