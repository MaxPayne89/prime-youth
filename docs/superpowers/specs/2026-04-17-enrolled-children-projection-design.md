# Enrolled Children in Conversation Headers

**Issue:** #551 — Show parent name and enrolled child names in conversation header
**Date:** 2026-04-17
**Status:** Approved

## Problem

When a provider opens a direct conversation, the header shows a generic "Conversation" title. There is no context about which children the conversation relates to. The provider must remember or scroll through messages to figure out who they are talking to and why.

## Solution

Extend the Messaging context's projection infrastructure to resolve and display enrolled child names alongside the parent name in conversation headers.

**Target format:** `Sarah Johnson for Emma, Liam`

- Single child: `Sarah Johnson for Emma`
- Multiple children: `Sarah Johnson for Emma, Liam`
- No enrolled children resolvable: fall back to parent name or generic "Conversation"
- Provider-side only — parents already know their own context

## Architecture Overview

The solution follows the event-driven projection pattern established by `ConversationSummaries`. Instead of adding ACL adapters for cross-context data resolution, we:

1. Create missing integration events in Enrollment and Family contexts
2. Build a new `EnrolledChildren` projection within Messaging that maintains a local lookup table populated from those events
3. Have a driving event handler translate cross-context events into an internal `enrolled_children_changed` domain event
4. Extend `ConversationSummaries` to react to that internal event with a simple field update

This avoids direct cross-context coupling — Messaging never queries Enrollment or Family at runtime. All data flows through events.

### Event Flow Diagram

```
Enrollment Context                Family Context
      |                                 |
  enrollment_created              child_created
  enrollment_cancelled            child_updated
      |                                 |
      +---------- PubSub --------------+
                    |
    Messaging: EnrolledChildren Projection (GenServer)
        - maintains messaging_enrolled_children table
        - re-derives child names on any change
        - emits enrolled_children_changed domain event
                    |
              DomainEventBus
                    |
    Messaging: ConversationSummaries Projection
        - updates enrolled_child_names column
                    |
            conversation_summaries table
                    |
        +----------+-----------+
        |                      |
    Show View              Index View
    (secondary read)    (already reads projection)
```

## New Integration Events

### Enrollment Context

**`enrollment_created`** (new domain event + integration promotion)

- Published from: `CreateEnrollment` command after successful persistence
- Topic: `integration:enrollment:enrollment_created`
- Payload:

```elixir
%{
  enrollment_id: String.t(),
  child_id: String.t(),
  parent_id: String.t(),
  parent_user_id: String.t(),  # identity_id — what Messaging uses
  program_id: String.t(),
  status: String.t()
}
```

Note: `parent_user_id` (identity_id) is included because Messaging identifies participants by user_id, not parent_id. The `CreateEnrollment` command already receives `identity_id` as a parameter.

**`enrollment_cancelled`** (existing — verify payload includes needed fields)

- Verify payload includes: `child_id`, `parent_id`, `program_id`
- Add `parent_user_id` if missing

### Family Context

**`child_created`** (new domain event + integration promotion)

- Published from: `CreateChild` command after successful persistence
- Topic: `integration:family:child_created`
- Payload:

```elixir
%{
  child_id: String.t(),
  parent_id: String.t(),
  first_name: String.t(),
  last_name: String.t()
}
```

**`child_updated`** (new domain event + integration promotion)

- Published from: `UpdateChild` command after successful persistence
- Topic: `integration:family:child_updated`
- Payload: same as `child_created`

### Messaging Context (fix)

**`conversation_created`** (existing — fix missing `program_id`)

The domain event currently carries `%{conversation_id, type, provider_id, participant_ids}` but omits `program_id`. This means the `ConversationSummaries` projection gets `program_id: nil` for direct conversations via the event path (only correct after bootstrap).

Fix: Add `program_id` to the domain event payload in `MessagingEvents.conversation_created/4` and propagate through the integration event.

### Messaging Internal

**`enrolled_children_changed`** (new domain event — internal to Messaging, not promoted to integration)

- Emitted by: `EnrolledChildren` projection handler
- Delivered via: PubSub topic `"messaging:enrolled_children_changed"` (consumed by `ConversationSummaries`)
- Payload:

```elixir
%{
  conversation_id: String.t(),
  enrolled_child_names: [String.t()]  # e.g. ["Emma", "Liam"] — sorted alphabetically
}
```

## EnrolledChildren Projection

### Table: `messaging_enrolled_children`

```sql
CREATE TABLE messaging_enrolled_children (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id uuid NOT NULL,
  program_id uuid NOT NULL,
  child_id uuid NOT NULL,
  child_first_name text,
  inserted_at timestamp NOT NULL DEFAULT now(),
  updated_at timestamp NOT NULL DEFAULT now(),
  CONSTRAINT messaging_enrolled_children_unique
    UNIQUE(parent_user_id, program_id, child_id)
);

CREATE INDEX idx_enrolled_children_parent_program
  ON messaging_enrolled_children(parent_user_id, program_id);

CREATE INDEX idx_enrolled_children_child_id
  ON messaging_enrolled_children(child_id);
```

`child_first_name` is nullable — handles the timing edge case where `enrollment_created` arrives before `child_created`. Bootstrap fills gaps on restart.

### GenServer: `Messaging.Adapters.Driven.Projections.EnrolledChildren`

Follows the exact pattern of `ConversationSummaries`:

- Subscribes to 5 event topics on init
- `handle_continue(:bootstrap)` populates from write tables
- Each event handler updates the lookup table, then triggers re-derivation
- Retry logic on bootstrap failure (same as ConversationSummaries)

**Event subscriptions:**

| Topic | Source |
|---|---|
| `integration:enrollment:enrollment_created` | Enrollment (new) |
| `integration:enrollment:enrollment_cancelled` | Enrollment (existing) |
| `integration:family:child_created` | Family (new) |
| `integration:family:child_updated` | Family (new) |
| `integration:messaging:conversation_created` | Messaging (existing) |

**Event handling:**

| Event | Lookup table action | Downstream |
|---|---|---|
| `enrollment_created` | Upsert row (name may be nil) | Re-derive and emit `enrolled_children_changed` |
| `enrollment_cancelled` | Delete row | Re-derive and emit `enrolled_children_changed` |
| `child_created` | Update `child_first_name` where `child_id` matches | Re-derive and emit `enrolled_children_changed` |
| `child_updated` | Update `child_first_name` where `child_id` matches | Re-derive and emit `enrolled_children_changed` |
| `conversation_created` | No table change | Look up names from table using event payload (not summary query — row may not exist yet), emit `enrolled_children_changed` |

**Re-derivation flow** (shared helper used by all handlers):

1. Query `messaging_enrolled_children` for `{parent_user_id, program_id}` — get list of non-nil `child_first_name` values, sorted alphabetically
2. Find affected conversation IDs:
   - For `enrollment_*` and `child_*` events: query `conversation_summaries` for `conversation_type = 'direct' AND program_id = X AND user_id = parent_user_id`
   - For `conversation_created`: extract `conversation_id` directly from the event payload (the summary row may not exist yet due to projection ordering)
3. For each `conversation_id`, publish `enrolled_children_changed` to PubSub topic `"messaging:enrolled_children_changed"` as a domain event

**Bootstrap:**

```sql
SELECT pp.identity_id AS parent_user_id,
       e.program_id,
       e.child_id,
       c.first_name AS child_first_name
FROM enrollments e
JOIN children c ON c.id = e.child_id
JOIN parent_profiles pp ON pp.id = e.parent_id
WHERE e.status IN ('pending', 'confirmed')
```

Upserted into `messaging_enrolled_children` with conflict handling on the unique constraint.

**Supervision:** Added to the application supervisor, started before `ConversationSummaries` so the lookup table is populated before ConversationSummaries bootstrap reads from it.

## ConversationSummaries Extension

### Migration

```sql
ALTER TABLE conversation_summaries
ADD COLUMN enrolled_child_names text[] DEFAULT '{}';
```

### Schema + Read Model

- `ConversationSummarySchema`: add `field :enrolled_child_names, {:array, :string}, default: []`
- `ConversationSummary` read model: add `enrolled_child_names: [String.t()]` with default `[]`

### New Event Handler

The projection subscribes to the `"messaging:enrolled_children_changed"` PubSub topic on init and handles incoming events:

```elixir
def handle_info({:domain_event, %DomainEvent{event_type: :enrolled_children_changed} = event}, state) do
  project_enrolled_children_changed(event)
  {:noreply, state}
end
```

Update is a simple bulk set on all rows for the conversation:

```sql
UPDATE conversation_summaries
SET enrolled_child_names = $names, updated_at = $now
WHERE conversation_id = $id
```

### Bootstrap Integration

During `ConversationSummaries.bootstrap_from_write_tables/0`, for each direct conversation with a `program_id`, query `messaging_enrolled_children` (within-context table) to populate the `enrolled_child_names` field.

## Web Layer

### Show View (`messaging_live_helper.ex`)

In `mount_conversation_show`, after loading the conversation from the write model, make a secondary read from `conversation_summaries` to get `enrolled_child_names`:

```elixir
enrolled_child_names = fetch_enrolled_child_names(conversation.id, user_id)
page_title = get_conversation_title(conversation, enrolled_child_names, other_participant_name)
```

**New `get_conversation_title` clauses:**

```elixir
# Direct conversation with enrolled children — provider sees "Sarah Johnson for Emma, Liam"
def get_conversation_title(%{type: :direct}, child_names, other_name)
    when child_names != [] and not is_nil(other_name) do
  formatted = Enum.join(child_names, ", ")
  "#{other_name} #{gettext("for")} #{formatted}"
end

# Direct conversation without children — fall back to other participant name
def get_conversation_title(%{type: :direct}, _child_names, other_name)
    when not is_nil(other_name) do
  other_name
end

# Existing clauses for broadcasts and fallback
def get_conversation_title(%{type: :program_broadcast, subject: subject}, _, _)
    when not is_nil(subject), do: subject

def get_conversation_title(%{type: :program_broadcast}, _, _),
    do: gettext("Program Broadcast")

def get_conversation_title(_conversation, _, _),
    do: gettext("Conversation")
```

The function signature changes from arity 1 to arity 3. Callers updated accordingly.

### Index View (conversation card)

The `conversation_card` component already receives `ConversationSummary` data including `enrolled_child_names`. For provider-variant conversation cards:

- Show child names as a subtitle below the parent name in smaller, muted text
- Format: `for Emma, Liam`
- Only render when `enrolled_child_names` is non-empty
- Parent variant does not display child names

### Internationalization

The "for" separator uses `gettext("for")` for English/German translation. Child names are proper nouns — no translation needed.

## Edge Cases

| Scenario | Behavior |
|---|---|
| Conversation created before any enrollment | `enrolled_child_names` stays `[]`, title falls back to parent name or "Conversation" |
| Enrollment created after conversation exists | `enrollment_created` event triggers re-derivation, projection updates, title changes on next page load |
| `child_first_name` nil (enrollment before child event) | Row stored with nil name, excluded from derived list. Bootstrap or next `child_created` event fills the gap |
| Child deleted (enrollments cancelled) | `enrollment_cancelled` event removes the row, child drops from list naturally |
| GDPR anonymization | No special handling — `enrolled_child_names` is derived from active enrollments, not persistent child data. Existing `message_data_anonymized` handles `other_participant_name` separately |
| Conversation has no `program_id` | Handler ignores — no program means no enrollment context to resolve |
| Multiple children in same program | All names appear in the list |

## Config and Supervision

**No new port/adapter DI needed** — the `EnrolledChildren` projection is a GenServer that queries its own table and uses `DomainEventBus` directly.

**Application supervisor (`application.ex`):** Add `EnrolledChildren` GenServer, started before `ConversationSummaries`.

**Boundary config (`messaging.ex`):** Already declares `deps: [KlassHero.Enrollment, KlassHero.Family]` — no change needed.

## Follow-up Issue

File a separate issue to migrate the conversation show view from the write model to a dedicated conversation-detail read model. This would make the projection layer the single source of truth for the show view, eliminating the current two-source read pattern. This is a larger CQRS evolution outside the scope of issue #551.

## Testing Strategy

### Unit Tests

- `EnrolledChildren` projection: bootstrap populates correctly, each event type updates the lookup table, re-derivation emits correct events
- `ConversationSummaries`: `enrolled_children_changed` event updates the field correctly
- `get_conversation_title/3`: all clause combinations (with children, without, broadcast, fallback)

### Integration Tests

- End-to-end: enrollment created → lookup updated → domain event emitted → summary updated
- End-to-end: child name updated → lookup updated → domain event emitted → summary updated
- Bootstrap ordering: `EnrolledChildren` bootstraps before `ConversationSummaries`

### LiveView Tests

- Provider show view: `<h1>` contains "Sarah Johnson for Emma" format
- Provider index view: conversation card subtitle shows child names
- Parent views: child names not displayed
- Fallback: no children → title shows parent name only

## Scope Summary

### In scope (this issue)

- New `enrollment_created` domain + integration event (Enrollment context)
- New `child_created` and `child_updated` domain + integration events (Family context)
- Fix `conversation_created` event to include `program_id` (Messaging context)
- New `messaging_enrolled_children` table + `EnrolledChildren` projection GenServer
- Extend `conversation_summaries` with `enrolled_child_names` column
- Update show view title composition
- Update index view conversation card (provider variant)
- Tests for all layers

### Out of scope (follow-up)

- Migrate show view to read entirely from projections (CQRS evolution)
- Real-time title updates via PubSub (title updates on next page load, not live)
