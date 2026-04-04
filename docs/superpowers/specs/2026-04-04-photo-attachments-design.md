# Photo Attachments in Messages

**Issue:** #362 — [FEATURE] Support photo attachments in messages
**Date:** 2026-04-04
**Status:** Design approved

## Overview

Add photo attachment support to the messaging system. Users can attach up to 5 images per message, with or without text. Attachments are stored in S3 (public bucket), persisted as a child entity of Message, and flow through the existing event-driven architecture. The ConversationSummaries projection is extended to support attachment-aware inbox previews.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Attachment model | Generic `Attachment` (not photo-specific) | Extensible to other file types later |
| Max per message | 5 | Covers common use cases without overcomplicating UI |
| Text requirement | Optional (content OR attachments) | Modern chat UX — no friction for photo-only messages |
| File size limit | 10 MB per file | Handles high-res phone photos comfortably |
| Storage bucket | Public S3 | Direct URLs, no signed URL overhead; access controlled at LiveView level |
| Soft-delete behavior | No `deleted_at` on attachment | Follows parent message lifecycle; filtered by `message.deleted_at` |
| ACL migration | Out of scope | Separate architectural concern; this feature doesn't touch cross-context queries |

## Architecture

Approach C: Separate persistence entity, use case orchestrates driven ports. No domain service — the `SendMessage` use case coordinates calls to `ForStoringFiles` (Shared), `ForManagingAttachments` (new), and `ForManagingMessages` (existing).

### Affected Bounded Context

**Messaging** (primary) — all new code lives here. **Shared** (reuse only) — existing `ForStoringFiles` port and `Storage` facade, no changes needed.

---

## 1. Domain Layer

### Attachment Model

New file: `lib/klass_hero/messaging/domain/models/attachment.ex`

```elixir
defstruct [
  :id,                # UUID
  :message_id,        # UUID — belongs to Message aggregate
  :file_url,          # String — public S3 URL
  :original_filename, # String — user's original filename
  :content_type,      # String — MIME type
  :file_size_bytes,   # Integer — size in bytes
  :inserted_at,       # DateTime
  :updated_at         # DateTime
]
```

**Validation rules (in `new/1`):**

- `file_url` — required
- `original_filename` — required
- `content_type` — required, must be in allowed types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`
- `file_size_bytes` — required, > 0, <= 10,485,760 (10 MB)

Allowed content types defined as a module attribute for easy extension.

### Message Model Changes

File: `lib/klass_hero/messaging/domain/models/message.ex`

- `content` becomes optional (can be `nil`)
- New field: `attachments` (list, defaults to `[]`)
- New validation: message must have non-empty `content` OR at least one attachment
- New validation: max 5 attachments per message

---

## 2. Persistence Layer

### Migration

New file: `priv/repo/migrations/*_create_message_attachments.exs`

```sql
CREATE TABLE message_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  original_filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  file_size_bytes BIGINT NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX message_attachments_message_id_index ON message_attachments(message_id);
```

Key decisions:
- `ON DELETE CASCADE` — retention policy hard-deletes cascade automatically
- `BIGINT` for file size — future-proofs beyond current 10 MB limit
- No `deleted_at` — attachments follow message lifecycle

### ConversationSummaries Migration

Add `has_attachments` boolean column (default `false`) to `conversation_summaries` table.

### Ecto Schema

New file: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/attachment_schema.ex`

- Fields mirror migration
- `belongs_to :message, MessageSchema`
- Single `create_changeset/2` — attachments are immutable

Update: `MessageSchema` — add `has_many :attachments, AttachmentSchema`, allow `content` to be `nil` in `create_changeset/2`.

### Mapper

New file: `lib/klass_hero/messaging/adapters/driven/persistence/mappers/attachment_mapper.ex`

Standard `to_domain/1` and `to_schema_attrs/1` following existing mapper pattern.

### Repository

New file: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository.ex`

Implements `ForManagingAttachments` with:

- `create_many/1` — bulk insert attachments
- `list_for_message/1` — fetch for single message
- `list_for_messages/1` — batch fetch for multiple messages (returns `%{message_id => [attachments]}`; messages with no attachments are omitted from the map; avoids N+1)
- `delete_for_expired_conversations/1` — queries and returns file URLs for attachments belonging to the given conversations (does NOT delete records itself — DB cascade handles that when the retention use case hard-deletes messages)

---

## 3. Port Contract

### ForManagingAttachments (Driven Port)

New file: `lib/klass_hero/messaging/domain/ports/for_managing_attachments.ex`

```elixir
@callback create_many([Attachment.t()]) :: {:ok, [Attachment.t()]} | {:error, term()}
@callback list_for_message(message_id :: Ecto.UUID.t()) :: [Attachment.t()]
@callback list_for_messages([message_id :: Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [Attachment.t()]}
@callback delete_for_expired_conversations([conversation_id :: Ecto.UUID.t()]) :: {:ok, [String.t()]}
```

No new port for file storage — uses existing `ForStoringFiles` from Shared context.

---

## 4. Use Case — SendMessage Changes

File: `lib/klass_hero/messaging/application/use_cases/send_message.ex`

### Signature

```elixir
def execute(conversation_id, sender_id, content, opts \\ [])
```

Signature unchanged. `opts` gains `:attachments` key — a list of file data maps:

```elixir
%{binary: <<...>>, filename: "photo.jpg", content_type: "image/jpeg", size: 2_400_000}
```

### Orchestration Flow

```
execute(conversation_id, sender_id, content, opts)
  1. Validate: content OR attachments present (else {:error, :empty_message})
  2. Validate attachments via domain model (type, size, count)
  3. Verify sender is participant (existing)
  4. Verify broadcast send permission (existing)
  5. Upload files to S3 via ForStoringFiles port
     - For each file: Storage.upload(:public, path, binary, content_type: ct)
     - Build Attachment domain models with returned URLs
     - On upload failure: clean up already-uploaded files, return {:error, :upload_failed}
  6. Ecto.Multi transaction:
     a. Create message (content potentially nil)
     b. Create attachments (bulk insert via ForManagingAttachments)
     c. Update sender last_read_at (existing)
  7. On transaction failure: clean up S3 files via ForStoringFiles.delete
  8. Publish enriched message_sent domain event (with attachment metadata)
  9. Return {:ok, message_with_attachments}
```

S3 uploads happen before the DB transaction. If uploads succeed but the transaction fails, the use case explicitly cleans up S3 files. This gives "all or nothing" at the application level.

### S3 Path Structure

Upload path format: `messaging/attachments/{message_id}/{uuid}{ext}`

- `message_id` groups files by message for easy bulk cleanup
- `uuid` ensures uniqueness (no filename collisions)
- `ext` preserves original extension for content-type inference
- Example: `messaging/attachments/550e8400-e29b-41d4-a716-446655440000/a1b2c3d4.jpg`

### Error Cases

| Scenario | Return |
|----------|--------|
| No content AND no attachments | `{:error, :empty_message}` |
| Invalid attachment (type/size/count) | `{:error, :invalid_attachments}` |
| S3 upload fails mid-batch | Clean up uploaded files → `{:error, :upload_failed}` |
| DB transaction fails after S3 | Clean up all S3 files → `{:error, reason}` |
| Not a participant | `{:error, :not_participant}` (existing) |

---

## 5. Event Flow & Projection Updates

### Domain Event — Enriched `message_sent`

Existing payload:

```elixir
%{conversation_id, message_id, sender_id, content, message_type, sent_at}
```

Enriched payload (backward compatible — `attachments` defaults to `[]`):

```elixir
%{
  conversation_id: uuid,
  message_id: uuid,
  sender_id: uuid,
  content: string | nil,
  message_type: :text,
  sent_at: datetime,
  attachments: [
    %{id: uuid, file_url: string, original_filename: string,
      content_type: string, file_size_bytes: integer}
  ]
}
```

### Integration Event

`PromoteIntegrationEvents` promotes the enriched event. Integration event version bumped (e.g., `1` → `2`) for contract clarity. Existing subscribers unaffected — they ignore the new field.

### No New Event Types

Attachments are part of the Message aggregate. The `message_sent` event is the single source of truth. No `attachment_uploaded` or `attachment_created` events needed.

### ConversationSummaries Projection Updates

The `message_sent` handler is extended:

- Sets `has_attachments` to `true` when event payload has non-empty `attachments` list
- Sets `has_attachments` to `false` for text-only messages
- `latest_message_content` stores the text content (or `nil` for photo-only)
- UI component uses `has_attachments` flag to render camera icon prefix in inbox preview

Bootstrap is updated to derive `has_attachments` from existing message data: a LEFT JOIN on `message_attachments` with an `EXISTS` subquery determines whether the latest message for each conversation has attachments.

### Retention Policy Extension

`EnforceRetentionPolicy` use case gains one step before existing hard-delete:

1. Call `ForManagingAttachments.delete_for_expired_conversations/1` → get S3 URLs
2. Delete S3 files via `ForStoringFiles.delete/2`
3. Hard-delete messages (DB cascade removes attachment records)

### Full Event Chain

```
LiveView (driving adapter)
  → consume_uploaded_entries, reads file bytes
  → calls SendMessage.execute(...)
    → ForStoringFiles.upload (S3)
    → Ecto.Multi: create message + attachments
    → DomainEventBus.dispatch(message_sent)
      ├→ NotifyLiveViews → PubSub "conversation:{id}" → LiveViews stream new message
      └→ PromoteIntegrationEvents → PubSub "integration:messaging:message_sent"
        → ConversationSummaries GenServer → updates has_attachments, latest_message_*, unread_count
```

---

## 6. LiveView & Components

### MessagingLiveHelper Changes

File: `lib/klass_hero_web/live/messaging_live_helper.ex`

Shared across all 3 show views (parent, provider, staff):

- Add `allow_upload(:attachments, accept: ~w(.jpg .jpeg .png .gif .webp), max_entries: 5, max_file_size: 10_485_760)` in mount
- Update `handle_event("send_message", ...)` to consume uploads and pass file data to use case
- LiveView's built-in upload machinery handles client-side previews via `@uploads.attachments.entries`

### messaging_components.ex Updates

File: `lib/klass_hero_web/components/messaging_components.ex`

**`message_bubble/1`:**
- Conditionally renders attachment grid when `message.attachments` is non-empty
- Single photo: full-width `<img>` with `loading="lazy"`
- 2+ photos: 2-column CSS grid
- Text (if present) renders below the photo grid

**`conversation_card/1`:**
- Uses `has_attachments` from projection for inbox preview
- Photo-only: shows camera icon + "Photo" (or "N Photos")
- Photo + text: shows camera icon + truncated text content

### Upload UI

- Attachment button (paperclip icon) in message input area
- Thumbnail previews with remove buttons (using `@uploads.attachments.entries`)
- Dashed "+" button to add more (up to 5)
- Error display for invalid files (too large, wrong type)
- No JS hooks needed — LiveView's `<.live_file_input>` handles file selection

---

## 7. Testing Strategy

### Domain Model Tests

- `test/klass_hero/messaging/domain/models/attachment_test.exs` — validation: allowed types, size limits, required fields, invalid type rejection
- `test/klass_hero/messaging/domain/models/message_test.exs` (update) — content-optional with attachments, empty message rejection

### Repository Tests

- `test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs` — `create_many/1`, `list_for_message/1`, `list_for_messages/1`, `delete_for_expired_conversations/1`

### Use Case Tests

- `test/klass_hero/messaging/application/use_cases/send_message_test.exs` (update):
  - Send with text + attachments
  - Send photo-only (no text)
  - Reject empty message (no content, no attachments)
  - Reject invalid attachment types
  - Reject oversized attachments
  - Reject > 5 attachments
  - S3 upload failure → cleanup and error
  - DB failure → S3 cleanup and error
  - Event payload includes attachment metadata

### Projection Tests

- `test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs` (update):
  - `message_sent` with attachments sets `has_attachments` true
  - Text-only message sets `has_attachments` false
  - Bootstrap derives `has_attachments` from existing data

### LiveView Tests

- Upload interaction via `file_input/4` and `render_upload/3`
- Message rendering with attachment images
- Error display for invalid files

### Test Fixtures

New `attachment_fixture/1` in `test/support/fixtures/messaging_fixtures.ex`.

---

## 8. Configuration & DI Wiring

### config/config.exs

```elixir
messaging: [
  # existing keys...
  for_managing_attachments: KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepository
]
```

### Boundary Exports

Update `lib/klass_hero/messaging.ex`:

```elixir
exports: [
  # existing...
  Domain.Models.Attachment
]
```

---

## Files Summary

### New Files (9)

| File | Layer |
|------|-------|
| `messaging/domain/models/attachment.ex` | Domain model |
| `messaging/domain/ports/for_managing_attachments.ex` | Port |
| `messaging/adapters/driven/persistence/schemas/attachment_schema.ex` | Schema |
| `messaging/adapters/driven/persistence/mappers/attachment_mapper.ex` | Mapper |
| `messaging/adapters/driven/persistence/repositories/attachment_repository.ex` | Repository |
| `priv/repo/migrations/*_create_message_attachments.exs` | Migration |
| `test/klass_hero/messaging/domain/models/attachment_test.exs` | Test |
| `test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs` | Test |
| Migration for `has_attachments` on `conversation_summaries` | Migration |

### Modified Files (10+)

| File | Change |
|------|--------|
| `messaging/domain/models/message.ex` | Optional content, attachments field |
| `messaging/adapters/driven/persistence/schemas/message_schema.ex` | has_many, nullable content |
| `messaging/application/use_cases/send_message.ex` | S3 upload orchestration, attachment creation |
| `messaging/domain/events/messaging_events.ex` | Enriched message_sent payload |
| `messaging/domain/events/messaging_integration_events.ex` | Version bump, attachment payload |
| `messaging/adapters/driven/projections/conversation_summaries.ex` | has_attachments projection |
| `messaging/adapters/driving/events/event_handlers/notify_live_views.ex` | Pass attachment data |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | allow_upload, consume uploads |
| `lib/klass_hero_web/components/messaging_components.ex` | Photo rendering, inbox preview |
| `lib/klass_hero/messaging.ex` | Boundary export |
| `config/config.exs` | DI wiring |
| `test/support/fixtures/messaging_fixtures.ex` | Attachment fixtures |
| Existing test files | New test cases |
