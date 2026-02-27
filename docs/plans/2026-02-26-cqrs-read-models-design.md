# CQRS Denormalized Read Models

## Context

The application uses DDD with Ports & Adapters. A three-tier event system (domain events, integration events, LiveView events) is already in place with handler registry, priority ordering, and PubSub broadcasting. One CQRS-lite projection already exists: `VerifiedProviders` (in-memory MapSet, event-driven sync).

Read paths currently query write tables, map through domain models, and often require cross-context joins or aggregations. As traffic grows, this becomes a bottleneck for read-heavy contexts.

## Decision

Introduce denormalized read tables for **Program Catalog** and **Messaging** — the two contexts with the highest read/write asymmetry and most expensive read queries. Writes stay untouched. Reads shift to purpose-built tables kept in sync via the existing integration event system.

**Flavor:** Denormalized read models in the same Postgres database. No event store. No event sourcing. Eventual consistency is acceptable.

## Design

### Foundation: Projection Infrastructure

#### ProjectionBehaviour

A shared behaviour in `lib/klass_hero/shared/` that every projection GenServer implements:

- `bootstrap/0` — rebuild the read table from write tables on startup (via `handle_continue(:bootstrap, ...)`)
- `handle_event/1` — process a single integration event to update the read table
- `subscribe_topics/0` — declare which PubSub topics this projection listens to

The base module handles: subscribing to topics on init, dispatching events to `handle_event/1`, logging.

#### No Event Store

Every projection has a `bootstrap/0` that rebuilds from write tables. If a projection crashes, it reboots, bootstraps, and catches up from live events going forward. An event store can be added later as an additive change (new handler that persists events) if audit trails or time-travel debugging are ever needed.

#### Supervision

Each projection GenServer lives in its own context's supervision tree. Program Catalog projections supervised under Program Catalog, Messaging projections under Messaging.

---

### Program Catalog: `program_listings` Read Table

#### Problem

Every listing query hits the `programs` write table, maps through `ProgramMapper.to_domain/1` (builds `Instructor` VO, `RegistrationPeriod` VO), and returns full domain `Program` structs even when the UI only needs a subset of fields.

#### Schema

```sql
program_listings (
  id                      UUID PRIMARY KEY,   -- same as programs.id
  title                   TEXT NOT NULL,
  description             TEXT,
  category                TEXT,
  age_range               TEXT,
  price                   DECIMAL,
  pricing_period          TEXT,
  location                TEXT,
  cover_image_url         TEXT,
  icon_path               TEXT,
  instructor_name         TEXT,               -- denormalized
  instructor_headshot_url TEXT,               -- denormalized
  start_date              DATE,
  end_date                DATE,
  meeting_days            TEXT[],
  meeting_start_time      TIME,
  meeting_end_time        TIME,
  season                  TEXT,
  registration_start_date DATE,
  registration_end_date   DATE,
  provider_id             UUID NOT NULL,
  provider_verified       BOOLEAN DEFAULT false,  -- denormalized from Provider context
  inserted_at             TIMESTAMP NOT NULL,
  updated_at              TIMESTAMP NOT NULL
)
```

Indexes:
- `(inserted_at DESC, id DESC)` — cursor pagination (matches current keyset pattern)
- `(category)` — category filtering
- `(provider_id)` — provider's programs

#### Projection: ProgramListingsProjection

Subscribes to:

| Integration Event | Action |
|---|---|
| `program_catalog:program_created` | INSERT row |
| `program_catalog:program_updated` | UPDATE row (new event, see below) |
| `provider:provider_verified` | SET `provider_verified = true` for all provider's programs |
| `provider:provider_unverified` | SET `provider_verified = false` for all provider's programs |

Bootstrap: queries `programs` write table + `VerifiedProviders` to populate all rows.

#### New Integration Event Required

`UpdateProgram` use case currently dispatches a `:program_schedule_updated` domain event but does not promote it to an integration event. A `program_updated` integration event must be added so the projection can react to any program field change (title, price, description, etc.).

#### VerifiedProviders Projection Unchanged

`VerifiedProviders` stays as-is. It still serves write-side validation. `ProgramListingsProjection` independently subscribes to the same provider events for its own denormalized column.

---

### Messaging: `conversation_summaries` Read Table

#### Problem

`ListConversations` is the most expensive read path. For a single inbox load it:
1. JOINs `conversations` to `participants` (filter by active user)
2. LEFT JOINs `messages` with GROUP BY to order by most recent message
3. Computes `unread_count` per conversation via another JOIN
4. Separately fetches other participants' display names from Accounts context
5. Maps through `ConversationMapper.to_domain/1`

`GetTotalUnreadCount` runs its own aggregate query across all conversations.

#### Schema

```sql
conversation_summaries (
  id                       UUID PRIMARY KEY,   -- synthetic
  conversation_id          UUID NOT NULL,
  user_id                  UUID NOT NULL,       -- one row PER participant PER conversation
  conversation_type        TEXT NOT NULL,        -- 'direct' | 'program_broadcast'
  provider_id              UUID NOT NULL,
  program_id               UUID,
  subject                  TEXT,
  other_participant_name   TEXT,                -- denormalized display name (direct convos)
  participant_count        INTEGER DEFAULT 0,   -- for broadcast convos
  latest_message_content   TEXT,                -- preview text
  latest_message_sender_id UUID,
  latest_message_at        TIMESTAMP,           -- for ordering
  unread_count             INTEGER DEFAULT 0,
  last_read_at             TIMESTAMP,
  archived_at              TIMESTAMP,
  inserted_at              TIMESTAMP NOT NULL,

  UNIQUE(conversation_id, user_id)
)
```

Indexes:
- `(user_id, archived_at, latest_message_at DESC)` — inbox query
- `(user_id) WHERE archived_at IS NULL` — partial index for unread aggregation
- `(conversation_id)` — event-driven updates

#### Why One Row Per User Per Conversation

A direct conversation between User A and User B produces two rows with independent `unread_count` and `other_participant_name`. The inbox query becomes a single indexed scan: `WHERE user_id = ? AND archived_at IS NULL ORDER BY latest_message_at DESC`.

`GetTotalUnreadCount` becomes: `SELECT SUM(unread_count) WHERE user_id = ? AND archived_at IS NULL`.

#### Projection: ConversationSummariesProjection

Subscribes to:

| Integration Event | Action |
|---|---|
| `messaging:conversation_created` | INSERT rows for each participant |
| `messaging:message_sent` | UPDATE `latest_message_*`, INCREMENT `unread_count` for all except sender |
| `messaging:messages_read` | SET `unread_count = 0`, update `last_read_at` for that user |
| `messaging:conversation_archived` | SET `archived_at` |
| `messaging:conversations_archived` | Bulk SET `archived_at` |
| `messaging:broadcast_sent` | Same as message_sent for broadcast type |
| `messaging:user_data_anonymized` | Anonymize `other_participant_name` for affected user |

Bootstrap: queries `conversations` + `participants` + `messages` to rebuild all summaries.

#### Missing Integration Event Promotions

Most Messaging domain events are not currently promoted to integration events. New `PromoteIntegrationEvents` handlers needed for: `conversation_created`, `message_sent`, `messages_read`, `conversation_archived`, `conversations_archived`. The pattern exists in Enrollment's handler.

#### `other_participant_name` Staleness

Populated on bootstrap from Accounts context. Accepted as eventually stale — names rarely change. Next bootstrap (deploy/restart) picks up changes. A `user_profile_updated` integration event can be added later if needed.

---

### Read Path Architecture

#### New Read Ports

Dedicated read ports separate from existing write ports.

**Program Catalog — `ForListingProgramSummaries`:**
- `list_paginated(limit, cursor, category)` — `{:ok, PageResult}`
- `list_for_provider(provider_id)` — `{:ok, [ProgramListing]}`
- `get_by_id(id)` — `{:ok, ProgramListing} | {:error, :not_found}`

**Messaging — `ForListingConversationSummaries`:**
- `list_for_user(user_id, opts)` — `{:ok, [ConversationSummary], has_more}`
- `get_total_unread_count(user_id)` — `{:ok, non_neg_integer()}`

#### Read DTOs

Lightweight structs in `domain/read_models/`. Not domain models — no business logic, no value objects, no invariants. Just data shaped for display.

- `ProgramListing` — flat struct matching `program_listings` table columns
- `ConversationSummary` — flat struct matching `conversation_summaries` table columns

Located in `domain/read_models/` because they're part of the context's public API (use cases return them, web layer consumes them).

#### Read Repositories

New adapter modules alongside existing write repositories:

```
adapters/driven/persistence/
  program_repository.ex              # existing — writes
  program_listings_repository.ex     # new — reads from projection
```

Query read tables directly, return read DTOs. No mappers needed — table schema matches DTO shape.

#### Use Case Changes

Read use cases switch to the new read port:
- `ListProgramsPaginated` → calls `@listings_repository.list_paginated(...)` instead of `@repository.list_programs_paginated(...)`
- `ListConversations` → calls `@summaries_repository.list_for_user(...)` instead of the current multi-query flow
- `GetTotalUnreadCount` → calls `@summaries_repository.get_total_unread_count(...)` instead of the current aggregate query

#### Single-Entity Fetches Stay on Write Tables

`GetProgramById` and `GetConversation` continue reading from write tables. Detail/edit views need the full domain model. The performance gain of denormalization matters for list queries, not single-row lookups.

---

## Change Summary

| Layer | Changes | Unchanged |
|---|---|---|
| Database | 2 new tables: `program_listings`, `conversation_summaries` | All existing tables |
| Shared | New `ProjectionBehaviour` | Event infrastructure |
| Program Catalog | New read port, read DTO, read repo, projection GenServer. New `program_updated` integration event | Write ports, write use cases, domain model, mapper |
| Messaging | New read port, read DTO, read repo, projection GenServer. ~5 new integration event promotions | Write ports, write use cases, domain model, mapper |
| Use Cases | Read use cases switch to read ports | Write use cases |
| Web Layer | Presenters accept read DTOs for list views | Detail/edit views |

## Rollout Path

Gradual, one context at a time. At any point the system works — write tables are always there as fallback.

1. Foundation: `ProjectionBehaviour` in shared
2. Program Catalog: migration, projection, read port/repo/DTO, switch read use cases
3. Messaging: migration, projection, read port/repo/DTO, switch read use cases

## Risks

| Risk | Mitigation |
|---|---|
| Read model staleness after projection crash | Bootstrap from write tables on restart |
| Projection handler bug leaves read table inconsistent | Periodic reconciliation job (future, if needed) |
| Every write-model schema change requires updating projection + read table | Limited to 2 contexts; manageable overhead |
| Missing integration events cause stale reads | Audit event coverage per context before implementing |
