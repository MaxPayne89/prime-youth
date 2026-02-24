# Invite Email Sending Design

**Date:** 2026-02-23
**Issue:** #176 (partial — email sending for bulk enrollment import)
**Scope:** Resend setup, Oban worker, token generation, email composition, status transition to `invite_sent`
**Out of scope:** Invite redemption flow (landing page, account creation, enrollment confirmation)

## Context

PR #192 merged the CSV import backend: parse → validate → dedup → persist as `pending` invites. The `bulk_enrollment_invites` table already has `invite_token`, `invite_sent_at`, and the status lifecycle `pending → invite_sent → registered → enrolled | failed`.

This design covers the next step: sending invitation emails to guardians after import.

## Architecture Decisions

- **Oban background jobs** — import returns immediately; emails sent async with per-invite retry
- **Domain event trigger** — import use case publishes `:bulk_invites_imported`; handler enqueues Oban jobs
- **One job per invite** — individual retry granularity; `Oban.insert_all/2` for bulk enqueue efficiency
- **HTML + text fallback** — branded email with CTA button; plain text for clients that don't render HTML
- **Unique token per invite** — 32-byte random token for `/invites/:token` URLs
- **Port/adapter for email** — `ForSendingInviteEmails` port, `InviteEmailNotifier` adapter

## 1. Resend + Swoosh Configuration

### Production (`config/runtime.exs`)

```elixir
config :klass_hero, KlassHero.Mailer,
  adapter: Swoosh.Adapters.Resend,
  api_key: System.get_env("RESEND_API_KEY") || raise("RESEND_API_KEY not set")
```

`Swoosh.ApiClient.Req` already configured in `prod.exs`. Dev stays `Swoosh.Adapters.Local`, test stays `Swoosh.Adapters.Test`.

### Shared sender config (`config/config.exs`)

```elixir
config :klass_hero, :mailer_defaults,
  from: {"KlassHero", "noreply@mail.klasshero.com"}
```

Update `UserNotifier` to read from this config instead of hardcoded `"contact@example.com"`.

## 2. Domain Event + Handler Wiring

### Event: `:bulk_invites_imported`

Published from `ImportEnrollmentCsv` after `persist_batch` succeeds.

```elixir
DomainEvent.new(:bulk_invites_imported, provider_id, :enrollment, %{
  provider_id: provider_id,
  program_ids: program_ids,
  count: count
})
```

### Handler: `EnqueueInviteEmails`

Location: `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails.ex`

1. Query `pending` invites without tokens for the given `program_ids`
2. Generate unique token per invite
3. Bulk-update invites with tokens (single query)
4. Enqueue Oban jobs via `Oban.insert_all/2`

Registered on Enrollment DomainEventBus in `application.ex`:

```elixir
{:bulk_invites_imported,
 {EnqueueInviteEmails, :handle}}
```

### Idempotency

Handler queries for invites where `status = "pending" AND invite_token IS NULL`. Re-dispatching the event won't re-enqueue already-tokened invites.

## 3. Oban Worker

### Queue

New `:email` queue with concurrency 5:

```elixir
queues: [default: 10, messaging: 5, cleanup: 2, email: 5]
```

### Worker: `SendInviteEmailWorker`

Location: `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex`

- Queue: `:email`
- Max attempts: 3
- Args: `%{"invite_id" => invite_id}`

Flow:
1. Fetch invite by ID
2. Guard: skip if status != `"pending"` or token is missing
3. Build email via `InviteEmailNotifier.send_invite/2`
4. On success: transition `pending → invite_sent`, set `invite_sent_at`
5. On failure: transition to `failed` with `error_details`

### Token Generation

```elixir
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
```

32 bytes = 256 bits entropy. Schema already has unique index on `invite_token`.

## 4. Email Composition

### Port: `ForSendingInviteEmails`

Location: `lib/klass_hero/enrollment/domain/ports/for_sending_invite_emails.ex`

```elixir
@callback send_invite(invite :: map(), invite_url :: String.t()) ::
  {:ok, term()} | {:error, term()}
```

### Adapter: `InviteEmailNotifier`

Location: `lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex`

- Reads sender from `:mailer_defaults` config
- Builds Swoosh email with HTML body + text body
- Subject: `"You're invited to enroll {child_first_name} in {program_name}"`
- HTML body: branded layout, program name, child name, CTA button → `/invites/{invite_token}`
- Text fallback: same info with raw URL
- Delivers via `KlassHero.Mailer.deliver/1`

### Config registration

```elixir
# config/config.exs
config :klass_hero, :enrollment,
  ...,
  for_sending_invite_emails: InviteEmailNotifier
```

### Program name resolution

The invite schema stores `program_id` but not the program name. The worker needs the name for the email subject/body. Options:
- The `EnqueueInviteEmails` handler can batch-fetch program names via the `ProgramCatalogACL` and include `program_name` in the Oban job args
- This avoids an extra DB query per worker execution

## 5. Repository Additions

New callbacks on `ForStoringBulkEnrollmentInvites` port:

- `list_pending_without_token(program_ids)` — invites where `status = "pending"` and `invite_token IS NULL`
- `bulk_assign_tokens([{invite_id, token}])` — single UPDATE query
- `get_by_id(invite_id)` — fetch single invite
- `transition_status(invite, attrs)` — uses existing `transition_changeset/2`

## 6. File Map

| Component | Path |
|-----------|------|
| Resend config | `config/runtime.exs` |
| Mailer defaults | `config/config.exs` |
| Oban email queue | `config/config.exs` |
| Domain event publish | `lib/klass_hero/enrollment/application/use_cases/import_enrollment_csv.ex` |
| Event handler | `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails.ex` |
| Oban worker | `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex` |
| Email port | `lib/klass_hero/enrollment/domain/ports/for_sending_invite_emails.ex` |
| Email adapter | `lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex` |
| Repository additions | `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex` |
| Port additions | `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex` |
| Bus registration | `lib/klass_hero/application.ex` |
| UserNotifier update | `lib/klass_hero/accounts/user_notifier.ex` |

## 7. Testing

- **InviteEmailNotifier** — email struct correctness (subject, from, to, HTML/text bodies)
- **SendInviteEmailWorker** — success → `invite_sent`, failure → `failed`, skip already-sent
- **EnqueueInviteEmails** — token generation, bulk enqueue via `Oban.Testing`
- **Repository** — `list_pending_without_token`, `bulk_assign_tokens`, `transition_status`
- **Integration** — CSV import → event → handler → worker → email sent (Swoosh test adapter)
