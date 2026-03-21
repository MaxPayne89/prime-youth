# Admin Email Feature Fixes — Design Spec

**Date:** 2026-03-21
**Branch:** `fix/admin-email-feature`
**Status:** Approved

## Problem Statement

Four issues identified with the recently shipped admin email receiving/replying feature:

1. **Email body missing** — Resend's `email.received` webhook only sends metadata (subject, from, to). The body (`html`, `text`) and headers must be fetched separately via `GET /emails/receiving/{id}`.
2. **Reply textarea not clearing** — After sending a reply, the textarea retains the sent text. LiveView's morphdom skips patching form inputs after `phx-submit`; a `push_event` + JS hook is needed.
3. **Replies not threaded** — The `message_id` from the webhook payload (`data["message_id"]`) is never stored. The reply use case tries to extract it from `email.headers`, which is empty since headers aren't fetched. Replies arrive without `In-Reply-To` headers.
4. **Sent replies not visible** — `ReplyToEmail` sends via Swoosh and returns without persisting anything. The admin dashboard has no way to show which emails were replied to or what was sent.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Content fetch timing | Oban job after webhook | Not time-critical; decouples webhook response from Resend API availability |
| Content status tracking | `content_status` field (`pending` / `fetched` / `failed`) | Admin sees email arrived immediately; async nature is explicit; failures are visible |
| Reply persistence | Separate `email_replies` table | Supports multiple replies per email; stores full content for accountability; keeps `inbound_emails` focused on received data |
| Resend API client | New port (`ForFetchingEmailContent`) + adapter | Consistent with project's DDD/Ports & Adapters; testable via mock adapter |
| Reply delivery | Oban job with optimistic UI | Persist reply record immediately (status `:sending`), deliver async; admin sees reply instantly, resilient to Resend downtime |
| `message_id` storage | Dedicated column on `inbound_emails` | Available immediately from webhook; threading shouldn't depend on content fetch succeeding |
| Oban worker abstraction | Port (`ForSchedulingEmailJobs`) + adapter | Use cases remain decoupled from Oban; consistent with project architecture |

## Data Model Changes

### `inbound_emails` table — new columns

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `message_id` | `string` | `nil` | Original Message-ID from webhook, used for reply threading |
| `content_status` | `string` | `"pending"` | Tracks content fetch lifecycle: `pending` -> `fetched` / `failed` |

- `message_id` populated immediately from webhook (`data["message_id"]`)
- `content_status` starts as `"pending"`, updated by `FetchEmailContentWorker`
- `body_html`, `body_text`, `headers` remain nullable, populated by content fetch job

### New `email_replies` table

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | `binary_id` | PK | |
| `inbound_email_id` | `binary_id` | FK -> `inbound_emails`, NOT NULL | Links reply to received email |
| `body` | `text` | NOT NULL | What was sent |
| `sent_by_id` | `binary_id` | FK -> `users`, NOT NULL | Who sent it |
| `status` | `string` | NOT NULL, default `"sending"` | `sending` -> `sent` / `failed` |
| `resend_message_id` | `string` | nullable | Resend's ID for the sent reply |
| `sent_at` | `utc_datetime_usec` | nullable | Set when delivery confirmed |
| `inserted_at` / `updated_at` | timestamps | | |

Indexes: `inbound_email_id`, `sent_by_id`, `status`

### Domain model additions

- `InboundEmail` struct gains `message_id` (string) and `content_status` (atom: `:pending` / `:fetched` / `:failed`)
- New `EmailReply` domain model: `id`, `inbound_email_id`, `body`, `sent_by_id`, `status` (`:sending` / `:sent` / `:failed`), `resend_message_id`, `sent_at`

## Ports & Adapters

### New port: `ForFetchingEmailContent`

```elixir
@callback fetch_content(email_id :: String.t()) ::
  {:ok, %{html: String.t() | nil, text: String.t() | nil, headers: map()}} |
  {:error, term()}
```

**Adapter:** `ResendEmailContentAdapter` — uses `Req` to call `GET https://api.resend.com/emails/receiving/{id}` with bearer token auth. Maps HTTP responses to domain errors (`:not_found`, `:rate_limited`, `:server_error`, `:timeout`).

### New port: `ForManagingEmailReplies`

```elixir
@callback create(attrs :: map()) :: {:ok, EmailReply.t()} | {:error, term()}
@callback update_status(id :: binary(), status :: String.t(), attrs :: map()) :: {:ok, EmailReply.t()} | {:error, term()}
@callback list_by_email(inbound_email_id :: binary()) :: {:ok, [EmailReply.t()]}
```

**Adapter:** Standard Ecto repository (schema, mapper, queries, repo) following `InboundEmailRepository` pattern.

### New port: `ForSchedulingEmailJobs`

```elixir
@callback schedule_content_fetch(email_id :: binary(), resend_id :: String.t()) ::
  {:ok, term()} | {:error, term()}

@callback schedule_reply_delivery(reply_id :: binary()) ::
  {:ok, term()} | {:error, term()}
```

**Adapter:** `ObanEmailJobScheduler` — builds and inserts Oban job changesets. Only module that knows about Oban.

### Existing port change: `ForManagingInboundEmails`

New callback:

```elixir
@callback update_content(id :: binary(), attrs :: map()) ::
  {:ok, InboundEmail.t()} | {:error, term()}
```

Used by content fetch worker to fill in `body_html`, `body_text`, `headers`, and set `content_status`.

## Oban Workers

### `FetchEmailContentWorker`

- **Queue:** `email` (1 worker, rate-limit aware)
- **Max attempts:** 3 (exponential backoff, 30s base, 429-aware)
- **Triggered by:** `ReceiveInboundEmail` via `ForSchedulingEmailJobs.schedule_content_fetch/2`
- **Args:** `%{"email_id" => uuid, "resend_id" => resend_email_id}`
- **Flow:** Fetch content via port -> update email with body/headers/content_status via repo

### `SendEmailReplyWorker`

- **Queue:** `email`
- **Max attempts:** 3
- **Triggered by:** `ReplyToEmail` via `ForSchedulingEmailJobs.schedule_reply_delivery/1`
- **Args:** `%{"reply_id" => uuid}`
- **Flow:** Fetch reply + inbound email -> build Swoosh email with `In-Reply-To` from `message_id` -> deliver -> update reply status

## Use Case Changes

### `ReceiveInboundEmail` — updated flow

```
Webhook -> Controller -> ReceiveInboundEmail
                           |-- Store email (message_id from data, content_status: "pending")
                           |-- schedule_content_fetch(email.id, email.resend_id)
```

Controller additionally extracts `data["message_id"]` and passes it in attrs.

### `ReplyToEmail` — refactored flow

```
Admin clicks Send -> LiveView -> ReplyToEmail
                                   |-- Persist EmailReply (status: "sending")
                                   |-- schedule_reply_delivery(reply.id)
                                   |-- Return {:ok, reply}
```

No longer calls `KlassHero.Mailer.deliver/1` directly. Returns `EmailReply` domain model instead of `Swoosh.Email`.

## Admin UI Changes

### Index view

- Content status indicator: `:pending` shows spinner/label, `:failed` shows warning badge
- "Replied" indicator for emails with associated replies

### Show view — content area

- `:pending` -> "Content is being fetched..." placeholder
- `:failed` -> "Failed to fetch email content" with "Retry" button (enqueues new content fetch)
- `:fetched` -> Sanitized HTML / plain text fallback (existing behavior)

### Show view — reply section

- Reply list below the form showing all sent replies: body, sender, timestamp, delivery status
- `:failed` replies get a "Retry" button
- New reply appears immediately with `:sending` status after form submit

### Form clearing (issue 2 fix)

- Add `phx-hook="AutoResizeTextarea"` to reply textarea
- Add `push_event("clear_message_input", %{})` in `submit_reply` handler
- Matches existing pattern from `messaging_live_helper.ex:167-168`

## Error Handling

### Content fetch failures

- 3 retries with exponential backoff (30s base, 429-aware)
- After exhaustion: `content_status` set to `"failed"`, admin sees error with retry option
- Webhook metadata (subject, from, message_id) always available regardless of fetch status

### Reply delivery failures

- 3 retries with same backoff strategy
- After exhaustion: `EmailReply.status` set to `"failed"`, visible in UI with retry option
- Retry enqueues new job for same reply record

### Resend API client error mapping

| HTTP Status | Domain Error |
|-------------|-------------|
| 200 | `{:ok, content}` |
| 404 | `{:error, :not_found}` |
| 429 | `{:error, :rate_limited}` |
| 5xx | `{:error, :server_error}` |
| Timeout | `{:error, :timeout}` |

### Edge cases

- **Content never fetched (Resend deletes email):** `content_status` stays `"failed"`, metadata preserved
- **Worker crashes before delivery:** Oban retry picks it up; reply stays `:sending`
- **Duplicate webhook:** Existing `resend_id` unique constraint handles dedup; content fetch is idempotent

## Testing Strategy

### Unit tests

- `EmailReply` domain model: validation, status defaults, transitions
- `InboundEmail`: new `message_id` and `content_status` fields

### Repository tests

- `InboundEmailRepository.update_content/2`
- `EmailReplyRepository`: create, update_status, list_by_email

### Use case tests

- `ReceiveInboundEmail`: stores `message_id`, sets `content_status: :pending`, calls `schedule_content_fetch`
- `ReplyToEmail`: persists `EmailReply` with `:sending`, calls `schedule_reply_delivery`

### Adapter tests

- `ResendEmailContentAdapter`: mock HTTP responses, verify parsing, error handling
- `ObanEmailJobScheduler`: verify correct jobs enqueued with expected args

### Worker tests (Oban inline mode)

- `FetchEmailContentWorker`: happy path (fetched), failure path (failed status)
- `SendEmailReplyWorker`: happy path (sent, resend_message_id stored), failure path

### LiveView tests

- Index: content status indicators, replied badge
- Show: content placeholder for pending, error for failed, retry button
- Show: reply list with status indicators
- Reply form: clears after submit (regression for issue 2)

### Webhook controller tests

- Updated to verify `message_id` extraction from `data["message_id"]`

## Configuration

```elixir
# config/config.exs
config :klass_hero, :messaging,
  for_fetching_email_content: ResendEmailContentAdapter,
  for_managing_email_replies: EmailReplyRepository,
  for_scheduling_email_jobs: ObanEmailJobScheduler,
  # existing entries unchanged
  for_managing_inbound_emails: InboundEmailRepository,
  ...
```

## File Inventory

### New files

| File | Purpose |
|------|---------|
| `messaging/domain/models/email_reply.ex` | EmailReply domain model |
| `messaging/domain/ports/for_fetching_email_content.ex` | Content fetch port |
| `messaging/domain/ports/for_managing_email_replies.ex` | Reply repository port |
| `messaging/domain/ports/for_scheduling_email_jobs.ex` | Job scheduling port |
| `messaging/adapters/driven/resend_email_content_adapter.ex` | Resend API client |
| `messaging/adapters/driven/oban_email_job_scheduler.ex` | Oban job scheduler adapter |
| `messaging/adapters/driven/persistence/schemas/email_reply_schema.ex` | Ecto schema |
| `messaging/adapters/driven/persistence/repositories/email_reply_repository.ex` | Ecto repo |
| `messaging/adapters/driven/persistence/mappers/email_reply_mapper.ex` | Schema <-> domain mapper |
| `messaging/adapters/driven/persistence/queries/email_reply_queries.ex` | Query builders |
| `messaging/workers/fetch_email_content_worker.ex` | Oban worker for content fetch |
| `messaging/workers/send_email_reply_worker.ex` | Oban worker for reply delivery |
| `priv/repo/migrations/TIMESTAMP_add_email_content_and_replies.exs` | Migration |

### Modified files

| File | Change |
|------|--------|
| `messaging/domain/models/inbound_email.ex` | Add `message_id`, `content_status` fields |
| `messaging/domain/ports/for_managing_inbound_emails.ex` | Add `update_content` callback |
| `messaging/adapters/driven/persistence/schemas/inbound_email_schema.ex` | Add new columns |
| `messaging/adapters/driven/persistence/mappers/inbound_email_mapper.ex` | Map new fields |
| `messaging/adapters/driven/persistence/repositories/inbound_email_repository.ex` | Implement `update_content` |
| `messaging/application/use_cases/receive_inbound_email.ex` | Store `message_id`, enqueue content fetch |
| `messaging/application/use_cases/reply_to_email.ex` | Persist reply, enqueue delivery |
| `messaging/repositories.ex` | Add new repository accessors |
| `messaging.ex` | Add new public API delegates |
| `klass_hero_web/controllers/resend_webhook_controller.ex` | Extract `data["message_id"]` |
| `klass_hero_web/live/admin/emails_live.ex` | Content status UI, reply list, form clearing |
| `klass_hero_web/live/admin/emails_live.html.heex` | Template updates |
| `config/config.exs` | Add new port config entries |
| `test/support/fixtures/messaging_fixtures.ex` | Add reply fixtures |

## Out of Scope

- PubSub real-time updates for admin dashboard (filed as [#493](https://github.com/MaxPayne89/klass-hero/issues/493))
- Attachment fetching/display
- Email forwarding
- Admin email search/full-text
