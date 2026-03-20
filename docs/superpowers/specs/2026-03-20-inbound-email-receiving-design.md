# Inbound Email Receiving via Resend

**Issue:** #429
**Date:** 2026-03-20
**Context:** Messaging bounded context (Approach A — extend existing context)

## Overview

Enable admins to receive, read, and reply to inbound emails within the admin panel. Resend handles email reception (MX records already configured on Cloudflare). The application receives email payloads via webhook, stores them, and presents them in a custom admin LiveView.

## Data Model

### `inbound_emails` table

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | PK |
| `resend_id` | `string` | Resend's email ID (dedup + API reference) |
| `from_address` | `string` | Sender email |
| `from_name` | `string`, nullable | Sender display name |
| `to_addresses` | `{:array, :string}` | Recipient list |
| `subject` | `string` | |
| `body_html` | `text`, nullable | Raw HTML body (stored as-is, sanitized on render) |
| `body_text` | `text`, nullable | Plain text fallback |
| `cc_addresses` | `{:array, :string}`, nullable | CC recipients |
| `headers` | `map` | Raw headers as JSON (array format: `[%{"name" => "...", "value" => "..."}]`) |
| `status` | `string` | `unread`, `read`, `archived` |
| `read_by_id` | `uuid`, nullable, FK → users | Who first read it |
| `read_at` | `utc_datetime_usec`, nullable | When first read |
| `received_at` | `utc_datetime_usec` | When Resend received it |
| `inserted_at` / `updated_at` | timestamps | |

### Domain model

`KlassHero.Messaging.Domain.Models.InboundEmail` — pure struct following the same pattern as `Messaging.Domain.Models.Message`. Includes status transitions and validation.

### Key decisions

- Store raw HTML, sanitize at render time — avoids data loss if sanitization improves later.
- `status` as string enum (`unread`, `read`, `archived`) — extensible beyond boolean flags.
- No attachments in v1. Resend webhook payload includes attachment metadata, but serving them securely adds complexity. Good follow-up issue.

## Webhook Endpoint

### Route

`POST /webhooks/resend` — uses `:api` pipeline (no CSRF, no session).

### Controller

`KlassHeroWeb.ResendWebhookController`

### Flow

1. Receive POST from Resend with `email.received` event payload.
2. Verify webhook signature via Svix headers (`svix-id`, `svix-timestamp`, `svix-signature`).
3. Parse payload, extract email fields.
4. Deduplicate by `resend_id` (idempotent — ignore if already stored).
5. Persist to `inbound_emails` table.
6. Return `200 OK` (Resend retries on non-2xx).

### Security

- Webhook signing secret stored as env var: `RESEND_WEBHOOK_SECRET`.
- Signature verification using the `svix` Hex package (handles timestamp tolerance, multiple signatures, base64 encoding). Timestamp tolerance: 5 minutes (Svix default).
- Raw body cached before JSON parsing for signature verification (custom body reader plug).

### Resend payload structure (`email.received`)

```json
{
  "type": "email.received",
  "data": {
    "email_id": "...",
    "from": "sender@example.com",
    "to": ["hello@klasshero.com"],
    "subject": "...",
    "html": "...",
    "text": "...",
    "headers": [...],
    "created_at": "..."
  }
}
```

### No Oban worker needed

Webhook handler is lightweight (validate + insert). Notifications ("new email received") would go through Oban if added later.

## HTML Sanitization

### Dependency

`html_sanitize_ex` — Elixir HTML sanitizer built on `mochiweb_html` parser.

### Module

`KlassHero.Messaging.Adapters.Driven.EmailSanitizer` — placed in adapters since it wraps an external library (`html_sanitize_ex`), not a pure domain service.

### Strategy

**Allowed tags:** `<p>`, `<br>`, `<div>`, `<span>`, `<table>`, `<tr>`, `<td>`, `<th>`, `<ul>`, `<ol>`, `<li>`, `<a>`, `<b>`, `<i>`, `<strong>`, `<em>`, `<h1>`–`<h6>`, `<blockquote>`, `<pre>`, `<code>`, `<hr>`

**Stripped:** `<script>`, `<iframe>`, `<form>`, `<input>`, `<object>`, `<embed>`, all event handler attributes (`onclick`, `onerror`, etc.)

**Inline styles:** Allowed, but strip `position: fixed/absolute`, `z-index`, and CSS expressions/URLs — preserves email formatting without layout escapes.

**External images:** Replace `<img src="https://...">` with placeholder. Per-email "Load images" toggle in UI re-renders with images allowed.

**Links:** Keep `<a href>` but add `target="_blank"` and `rel="noopener noreferrer"`.

### Execution

Sanitization runs at render time in the LiveView, not on storage. Raw HTML stays intact in the DB.

### Fallback

If `body_html` is nil or sanitization produces empty output, display `body_text` with whitespace/newline formatting.

## Admin UI

### Routes

Added to existing `:admin_custom` live_session (admin layout, requires admin auth):

- `/admin/emails` — inbox list view
- `/admin/emails/:id` — email detail + reply view

### Inbox list (`Admin.EmailsLive`, `:index`)

- Table: status indicator (dot), from, subject, received_at.
- Unread emails visually distinct (bold text, colored dot).
- Sorted by `received_at` desc (newest first).
- Filter tabs: All | Unread | Archived.
- Row click navigates to detail and marks as read.

### Email detail (`Admin.EmailsLive`, `:show`)

- Header: from, to, subject, received_at, read_by.
- Body: sanitized HTML rendered via `raw/1`, with "Load images" button.
- Action buttons: Archive, Mark unread.
- Reply form at bottom: textarea + send button.

### Reply flow

- Sends via existing Swoosh/Resend outbound infrastructure (`KlassHero.Mailer`).
- From address: shared configured address (e.g. `hello@klasshero.com`).
- Sets `In-Reply-To` and `References` headers using original email's `Message-ID` extracted from stored headers (array format: find entry where `name == "Message-ID"` and use its `value`) — proper email threading.
- Reply is not stored as another `InboundEmail` — fire-and-forget send. Reply history is a follow-up.

### Sidebar

Add "Emails" link to admin sidebar (`admin.html.heex`) with `hero-envelope` icon and unread count badge.

## Architecture (DDD Placement)

All within the **Messaging** bounded context:

```
messaging/
├── domain/
│   ├── models/
│   │   └── inbound_email.ex                    # Pure domain struct
│   └── ports/
│       └── for_managing_inbound_emails.ex       # Repository port (matches ForManaging* convention)
├── application/
│   └── use_cases/
│       ├── receive_inbound_email.ex             # Webhook → store
│       ├── list_inbound_emails.ex               # Admin listing with filters
│       ├── get_inbound_email.ex                 # Fetch + mark read
│       └── reply_to_email.ex                    # Compose + send reply
├── repositories.ex                              # Update: add inbound_emails accessor
└── adapters/
    └── driven/
        ├── email_sanitizer.ex                   # HTML sanitization (adapter, wraps html_sanitize_ex)
        └── persistence/
            ├── schemas/inbound_email_schema.ex  # Ecto schema (matches *Schema convention)
            ├── repositories/inbound_email_repository.ex # Repository adapter (matches *Repository convention)
            ├── queries/inbound_email_queries.ex  # Filtered/sorted/paginated queries
            └── mappers/inbound_email_mapper.ex   # Schema ↔ domain
```

Web layer:

```
klass_hero_web/
├── controllers/
│   └── resend_webhook_controller.ex   # Webhook endpoint
├── plugs/
│   └── cache_raw_body.ex              # Raw body for signature verification
└── live/admin/
    └── emails_live.ex                 # Inbox + detail LiveView
```

## Configuration

- `RESEND_WEBHOOK_SECRET` — env var for webhook signature verification (set in `runtime.exs`).
- Shared reply-from address — configurable in `config.exs` (reuse existing `from` config or add dedicated key).
- Add to `config :klass_hero, :messaging` in `config.exs`: `for_managing_inbound_emails: KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository`
- Update `KlassHero.Messaging.Repositories` module with `inbound_emails/0` accessor.

### New dependencies

- `html_sanitize_ex` — HTML sanitization.
- `svix` — Resend webhook signature verification.

## Out of Scope (v1)

- Email attachments (storage + secure serving).
- Reply history tracking (storing outbound replies).
- Email notifications to admins when new email arrives.
- Full-text search across emails.
- Spam filtering.
