# System Note Dedup via ConversationSummaries Projection

**Issue:** [#431](https://github.com/MaxPayne89/prime-youth/issues/431) — `system_note_exists?` has 100-message dedup ceiling
**Date:** 2026-03-16
**Status:** Design approved

## Problem

`ReplyPrivatelyToBroadcast.system_note_exists?/3` fetches up to 100 messages via
`list_for_conversation(conversation_id, limit: 100)` and filters in-memory for
system notes containing a broadcast token. If a direct conversation exceeds 100
messages, the dedup check misses existing notes and inserts duplicates, silently
breaking idempotency.

## Design Decision

Extend the existing `ConversationSummaries` projection to track system note
tokens. The projection already subscribes to `message_sent` integration events
and maintains the `conversation_summaries` read table — adding system note
tracking requires no new GenServer, no new subscriptions, and follows the
established event-driven projection pattern.

### Why not SQL-only?

A targeted SQL `EXISTS` query on the `messages` table would fix the immediate
bug. However, messaging is a core selling point of the platform. As total message
volume grows, querying the `messages` table for dedup adds contention to an
already-hot table. The projection approach decouples the dedup check from the
write model entirely.

### Why not a separate projection?

A dedicated `SystemNoteProjection` GenServer would duplicate the `message_sent`
subscription and add operational complexity for what amounts to a single boolean
lookup. The `ConversationSummaries` projection is the natural home.

## Schema & Migration

Add a `system_notes` JSONB column (default `{}`) to the `conversation_summaries`
table with a GIN index using the default `jsonb_ops` operator class.

**Why `jsonb_ops` and not `jsonb_path_ops`:** The `jsonb_path_ops` operator class
only supports the `@>` containment operator. We need the `?` (key-existence)
operator for efficient token lookups, which requires the default `jsonb_ops`
class.

```sql
ALTER TABLE conversation_summaries
  ADD COLUMN system_notes jsonb NOT NULL DEFAULT '{}';

CREATE INDEX idx_conv_summaries_system_notes
  ON conversation_summaries USING gin (system_notes);
```

### Ecto Schema Update

Add the field to `ConversationSummarySchema`:

```elixir
field :system_notes, :map, default: %{}
```

### JSONB Structure

Keys are system note tokens in bracketed form (e.g. `[broadcast:uuid]`),
matching the token format used by `ReplyPrivatelyToBroadcast`. Values are
ISO 8601 timestamps of when the note was first projected:

```json
{
  "[broadcast:550e8400-e29b-41d4-a716-446655440000]": "2026-03-16T10:30:00Z",
  "[broadcast:6ba7b810-9dad-11d1-80b4-00c04fd430c8]": "2026-03-16T11:45:00Z"
}
```

**Token format consistency:** The use case constructs `token = "[broadcast:#{broadcast.id}]"`.
The projection extracts tokens from message content using the same bracketed
format. The query receives the token in the same form. One format throughout —
no stripping or transforming at any boundary.

The same `system_notes` data is replicated per participant row. This is
intentional — it's a read model, and the dedup check only needs "does this token
exist for this conversation?" which any participant's row can answer.

## Projection Changes (`ConversationSummaries`)

### Incremental projection

In `project_message_sent/1`, when the event payload's `message_type` is
`:system` (or `"system"`), extract the token from `content` using a regex
(`~r/\[broadcast:[^\]]+\]/`), then upsert the token into the `system_notes`
JSONB column for all rows of that conversation.

The JSONB update uses an `update:` clause within the query (not `set:` as
a second argument) to reference the current row's column value:

```elixir
from(s in ConversationSummarySchema,
  where: s.conversation_id == ^conversation_id,
  update: [set: [
    system_notes: fragment(
      "coalesce(system_notes, '{}')::jsonb || ?::jsonb",
      ^token_json
    ),
    updated_at: ^now
  ]]
)
|> Repo.update_all([])
```

Note: The fragment references `system_notes` as a raw column name string, not
as a bound variable `s.system_notes`. This is required because Ecto's
`update_all` does not support binding references in update expressions.

This is idempotent — re-projecting the same token overwrites with the same value.

### Bootstrap

During `bootstrap_from_write_tables/0`, fetch all system messages with broadcast
tokens:

```elixir
from(m in MessageSchema,
  where: m.message_type == "system" and is_nil(m.deleted_at),
  where: like(m.content, "[broadcast:%"),
  select: %{
    conversation_id: m.conversation_id,
    content: m.content,
    inserted_at: m.inserted_at
  }
)
```

Parse tokens from content, build `%{"[broadcast:uuid]" => timestamp}` maps per
conversation. Thread these maps into `build_conversation_entries` (becomes `/6`)
and `build_summary_entry` (becomes `/9`) so the `system_notes` key is included
in the entry map passed to `Repo.insert_all`. The new parameter is
`system_notes_by_conversation` (a map of `conversation_id => %{token => timestamp}`).

For conversations with no system notes, the entry uses the default `%{}`.

## Query Module & Port

### Query module

`ConversationSummaryQueries` in the persistence queries layer
(`lib/klass_hero/messaging/adapters/driven/persistence/queries/`).
Houses composable query builders for the `conversation_summaries` read table:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueries do
  import Ecto.Query
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema

  def base, do: from(s in ConversationSummarySchema)

  def by_conversation(query, conversation_id),
    do: where(query, [s], s.conversation_id == ^conversation_id)

  def has_system_note_key(query, token),
    do: where(query, [s], fragment("? \\? ?", s.system_notes, ^token))
end
```

The `?` operator checks key existence in the GIN-indexed JSONB column — O(1)
lookup regardless of table size.

### Port

Add `has_system_note?/2` to the existing `ForListingConversationSummaries` port
(not a new port). This port already defines the read-side contract for the
`conversation_summaries` table, and the existing `ConversationSummariesRepository`
adapter implements it. Adding the callback here keeps one port per read table.

```elixir
@callback has_system_note?(conversation_id :: String.t(), token :: String.t()) :: boolean()
```

The adapter implementation composes query builders and calls `Repo.exists?/1`.
This bypasses the `ConversationSummary` domain read model struct entirely —
`has_system_note?` is a boolean existence check, not a DTO query. No changes
needed to the `ConversationSummary` struct.

### Use case change

`ReplyPrivatelyToBroadcast` replaces the private `system_note_exists?/3` with:

```elixir
repos.conversation_summaries.has_system_note?(direct_conversation.id, token)
```

`Repositories.all/0` already has a `:conversation_summaries` key pointing to the
`ForListingConversationSummaries` adapter — no change needed there.

## Edge Cases

### Fresh deploy

Migration adds column with `DEFAULT '{}'`. All rows start with empty JSONB.
`has_system_note?/1` returns `false`, use case inserts the note, projection
picks it up via the `message_sent` event. No duplicates.

### Restart mid-operation

The projection subscribes before bootstrapping (events queued in GenServer
mailbox). Events arriving during bootstrap are applied after. The JSONB upsert
is idempotent — replaying an event that bootstrap already covered is harmless.

### GDPR / anonymization

System notes contain broadcast IDs (UUIDs), not personal data. No special
handling needed for `message_data_anonymized` events.

### Retention / archival

When conversations are deleted via retention policy, their
`conversation_summaries` rows are cleaned up too. `system_notes` goes with them.

## Testing Strategy

### Query module tests

Insert summary rows with known `system_notes` JSONB, assert `Repo.exists?/1`
returns correct booleans for present/absent tokens.

### Projection tests

- `message_sent` with `message_type: :system` and `[broadcast:uuid]` token
  → `system_notes` JSONB updated
- `message_sent` with `message_type: :text` → `system_notes` unchanged
- Duplicate system note events → idempotency (JSONB key not duplicated)
- Bootstrap with pre-existing system messages → `system_notes` populated

### Use case tests

- Existing idempotency test passes (now backed by projection)
- Regression test: create >100 regular messages before broadcast reply,
  verify dedup still works — validates the original bug is fixed
