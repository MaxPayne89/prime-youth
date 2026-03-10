# Persistent Critical Events Design

**Issue:** #325
**Date:** 2026-03-10
**Status:** Approved

## Problem

Critical events can be silently lost through two paths:
- **Domain events:** `EventDispatchHelper.dispatch/2` swallows handler failures with a log
- **Integration events:** PubSub is fire-and-forget with no acknowledgment or retry

Events marked `criticality: :critical` already exist in the codebase but receive no special treatment beyond louder logging.

## Solution

Add persistent delivery guarantees for events marked `:critical` using Oban as the durable retry mechanism. Normal events remain unchanged.

### Design Principles

- **Sync-first, Oban as fallback** for domain events — preserve existing synchronous dispatch behavior
- **Dual delivery** for integration events — PubSub for real-time, Oban for durability
- **Exactly-once processing** via a `processed_events` idempotency gate
- **Per-handler tracking** — composite key `{event_id, handler_ref}` since one event may have multiple handlers

## Conventions

### Canonical `handler_ref` Format

All components use a single canonical format for handler references:

```
"Elixir.KlassHero.Some.Module:handle_event"
```

Derived from `{module, function}` tuples as: `"#{inspect(module)}:#{function}"`.

This format is used consistently in:
- `processed_events` table rows
- `CriticalEventWorker` Oban job args
- `DomainEventBus.dispatch_critical/2` return values
- `EventSubscriber` critical event dispatch

A shared helper `CriticalEventDispatcher.handler_ref({module, function})` produces this string.

### Event Serialization Field Mapping

`CriticalEventSerializer` handles both event types. Field mapping:

| Field | DomainEvent | IntegrationEvent | Serialization |
|---|---|---|---|
| `event_id` | yes | yes | String (UUID), pass-through |
| `event_type` | yes | yes | `Atom.to_string/1` ↔ `String.to_existing_atom/1` |
| `aggregate_id` | yes | no | String/integer, pass-through |
| `aggregate_type` | yes | no | `Atom.to_string/1` ↔ `String.to_existing_atom/1` |
| `source_context` | no | yes | `Atom.to_string/1` ↔ `String.to_existing_atom/1` |
| `entity_type` | no | yes | `Atom.to_string/1` ↔ `String.to_existing_atom/1` |
| `entity_id` | no | yes | String/integer, pass-through |
| `occurred_at` | yes | yes | `DateTime.to_iso8601/1` ↔ `DateTime.from_iso8601/1` |
| `payload` | yes | yes | See payload key handling below |
| `metadata` | yes | yes | Atom keys → string keys → `String.to_existing_atom/1` |
| `version` | no | yes | Integer, pass-through |

**Payload key handling:** Payload maps use atom keys in the live system. After JSON round-trip, keys become strings. The deserializer atomizes payload keys using `String.to_existing_atom/1` — safe because payload keys are domain-defined and already loaded in the BEAM. Nested maps are atomized recursively.

## New Components

### 1. `processed_events` Table

Migration creating a deduplication table:
- `event_id` (UUID, not null)
- `handler_ref` (string, not null) — e.g. `"Elixir.KlassHero.SomeModule:handle_event"`
- `processed_at` (utc_datetime_usec, not null)
- Primary key: `{event_id, handler_ref}`

No auto-generated `id`. No timestamps macro. Minimal footprint — one row per critical event-handler pair.

No cleanup job for now. Table grows by one row per critical event-handler pair, which is tiny at current scale.

Ecto schema at `lib/klass_hero/shared/adapters/driven/persistence/schemas/processed_event.ex`. Internal to `CriticalEventDispatcher` only.

### 2. `CriticalEventDispatcher`

**Location:** `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex`

Domain service owning the exactly-once invariant.

**Public API:**
```elixir
@spec execute(String.t(), String.t(), (-> :ok | {:error, term()})) :: :ok | {:error, term()}
def execute(event_id, handler_ref, handler_fn)

@spec mark_processed(String.t(), String.t()) :: :ok
def mark_processed(event_id, handler_ref)

@spec handler_ref({module(), atom()}) :: String.t()
def handler_ref({module, function})
```

**`execute/3` logic:**
1. Begin transaction
2. `INSERT INTO processed_events (event_id, handler_ref, processed_at) ON CONFLICT DO NOTHING`
3. If 0 rows affected (conflict) → rollback, return `:ok` (already processed)
4. If 1 row affected → call `handler_fn.()`
5. If handler succeeds → commit transaction, return `:ok`
6. If handler fails → rollback (removes processed_events row), return `{:error, reason}`

The rollback-on-failure behavior is critical: if we mark an event as processed but the handler crashes, the Oban retry would see "already processed" and skip — defeating the purpose. The transaction ensures atomicity.

**`mark_processed/2`:** Convenience function for the success path of domain events. Inserts the `processed_events` row outside a transaction (no handler to wrap). Used by `EventDispatchHelper` when all handlers already succeeded synchronously.

**`handler_ref/1`:** Canonical derivation of handler_ref string from `{module, function}` tuple: `"#{inspect(module)}:#{function}"`.

### 3. `CriticalEventWorker`

**Location:** `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex`

Generic Oban worker for retrying failed critical event handlers.

**Configuration:**
- Queue: `:critical_events` (new, concurrency ~5)
- Max attempts: 3
- Standard Oban backoff

**Job args (JSON):**
```json
{
  "event_id": "uuid",
  "event_type": "invite_claimed",
  "event_kind": "domain | integration",
  "context": "Elixir.KlassHero.Enrollment",
  "handler": "Elixir.KlassHero.SomeModule:handle_event",
  "payload": { "..." }
}
```

**Execution:**
1. Parse `handler` string (split on `:`) → reconstitute `{module, function}` via `String.to_existing_atom/1`
2. Reconstruct `DomainEvent` or `IntegrationEvent` struct from `payload` + `event_kind` using `CriticalEventSerializer`
3. Call `CriticalEventDispatcher.execute(event_id, handler, fn -> module.function(event) end)`
4. Return `:ok` or `{:error, reason}` (Oban retries on error)

**Exhausted retries:** When all 3 attempts fail, Oban moves the job to `discarded` state. The worker implements `Oban.Worker`'s error reporting — the final failure is logged at `:error` level with full event context (event_id, event_type, handler, failure reason). ErrorTracker (already in the project) captures these for alerting. No dead-letter queue for now; operators can inspect discarded jobs via `Oban.Job` queries and manually retry if needed.

### 4. `CriticalEventSerializer`

**Location:** `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex`

Helper for round-tripping event structs through JSON (Oban args).

**Public API:**
```elixir
@spec serialize(DomainEvent.t() | IntegrationEvent.t()) :: map()
@spec deserialize(map()) :: DomainEvent.t() | IntegrationEvent.t()
```

See "Event Serialization Field Mapping" in the Conventions section for the complete field-by-field mapping. Payload keys are atomized recursively via `String.to_existing_atom/1` during deserialization.

### 5. `CriticalEventHandlerRegistry`

**Location:** `lib/klass_hero/shared/adapters/driven/events/critical_event_handler_registry.ex`

Config-driven mapping of integration event topics to handler modules for Oban job creation.

**Public API:**
```elixir
@spec handlers_for(String.t()) :: [{module(), atom()}]
```

**Configuration (config.exs):**
```elixir
config :klass_hero, :critical_event_handlers, %{
  "integration:enrollment:invite_claimed" => [
    {KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler, :handle_event}
  ],
  "integration:family:invite_family_ready" => [
    {KlassHero.Enrollment.Adapters.Driven.Events.InviteFamilyReadyHandler, :handle_event}
  ]
}
```

Only critical event subscriptions are registered here. Non-critical events continue using `EventSubscriber` via PubSub only.

## Modified Existing Modules

### `DomainEventBus`

**File:** `lib/klass_hero/shared/domain_event_bus.ex`

New function `dispatch_critical/2`:
- Same as `dispatch/2` but returns per-handler results with handler identity
- Return type: `{:ok, [{handler_ref, :ok | {:error, term()}}]}` where `handler_ref` is the `{module, function}` tuple stored at registration time
- Requires handler entries to carry their `{module, function}` origin — currently stored as anonymous fns via `Function.capture/3`. The init-time registration already receives `{module, function}` tuples; store these alongside the captured function.
- `dispatch/2` remains unchanged for normal events

Internal change to handler entry storage: from `{handler_fn, opts}` to `{handler_fn, opts, handler_identity}` where `handler_identity` is `{module, function}` or `:anonymous` for runtime-subscribed lambdas.

### `EventDispatchHelper`

**File:** `lib/klass_hero/shared/event_dispatch_helper.ex`

Changes to `dispatch/2`:
- If `DomainEvent.critical?(event)`:
  - Call `DomainEventBus.dispatch_critical/2` instead of `dispatch/2`
  - For each handler that succeeded → call `CriticalEventDispatcher.mark_processed(event_id, handler_ref)`
  - For each handler that failed → enqueue `CriticalEventWorker` with the event and handler identity
- Normal events → unchanged, exactly as today

Changes to `dispatch_or_error/2`:
- Does NOT enqueue Oban jobs for critical events. Callers of `dispatch_or_error` own error handling — they receive `{:error, reason}` and can roll back their own transaction. Enqueuing an Oban retry here would create a conflict: the caller rolls back the causal state, but Oban retries the handler against state that no longer exists.
- Critical events dispatched via `dispatch_or_error` still use `dispatch_critical/2` for handler identity, but only propagate the error — no Oban fallback.

### `EventSubscriber`

**File:** `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex`

Changes to `handle_info/2` for integration events:
- After receiving an event, check `IntegrationEvent.critical?(event)`
- If critical → wrap handler call in `CriticalEventDispatcher.execute(event_id, handler_ref, fn -> handler.handle_event(event) end)`
- If normal → call handler directly as today

This ensures the PubSub path inserts a `processed_events` row on success, so the parallel Oban job becomes a no-op.

The handler_ref is derived from the `EventSubscriber`'s `:handler` config option (already a module) plus `:handle_event` as the function name.

### `PubSubIntegrationEventPublisher`

**File:** `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex`

Changes to `publish/1`:
- After PubSub broadcast, check `IntegrationEvent.critical?(event)`
- If critical → look up handlers via `CriticalEventHandlerRegistry.handlers_for(topic)` → enqueue `CriticalEventWorker` per handler
- Normal events → unchanged

### `config.exs`

- Add `:critical_events` queue to Oban config: `critical_events: 5`
- Add `:critical_event_handlers` config map

## What Stays Unchanged

- Normal events — all existing behavior untouched
- `DomainEventBus.dispatch/2` — still synchronous, still returns flat failures (used for normal events)
- All existing Oban workers and queues
- Event struct APIs (`DomainEvent.new/5`, `IntegrationEvent.new/6`)
- `IntegrationEventPublishing` — callers don't change, routing happens in the publisher adapter

## Event Flows

### Critical Domain Event (sync-first, Oban fallback)

```
Use case calls EventDispatchHelper.dispatch(event, Context)
  → event is critical? → DomainEventBus.dispatch_critical(Context, event)
    Returns per-handler results with identity:
    ├── Handler A succeeded
    │   → CriticalEventDispatcher.mark_processed(event_id, handler_ref_A)
    │
    └── Handler B failed
        → CriticalEventWorker enqueued for handler B
        → Oban picks up job → CriticalEventDispatcher.execute(event_id, handler_ref_B, handler_fn)
          ├── Not yet processed → runs handler in transaction
          └── Already processed → no-op
```

### Critical Integration Event (dual delivery)

```
PubSubIntegrationEventPublisher.publish(event)
  → event is critical?
  ├── PubSub broadcast (real-time)
  │   → EventSubscriber receives → CriticalEventDispatcher.execute(event_id, handler_ref, handler_fn)
  │   → Row inserted in processed_events on success
  │
  └── CriticalEventWorker enqueued per handler (durable)
      → Oban picks up job → CriticalEventDispatcher.execute(event_id, handler_ref, handler_fn)
        ├── Already processed (PubSub won) → no-op, returns :ok
        └── Not yet processed (PubSub failed) → runs handler in transaction
```

### Normal Events (unchanged)

```
Domain:      EventDispatchHelper → DomainEventBus.dispatch → handlers (sync, fire-and-forget)
Integration: PubSubIntegrationEventPublisher → PubSub broadcast → EventSubscriber → handler
```

## Test Strategy

### `CriticalEventDispatcher` Tests
- `execute/3`: Handler succeeds → row in `processed_events`, handler ran once
- `execute/3`: Handler fails → no row in `processed_events` (rolled back), error returned
- `execute/3`: Same event+handler called twice → handler runs only once, second call returns `:ok`
- `mark_processed/2`: Inserts row, second call is no-op
- `handler_ref/1`: Produces canonical `"Elixir.Module:function"` string

### `CriticalEventWorker` Tests
- Deserializes event and handler correctly, calls dispatcher
- Returns `{:error, ...}` on handler failure (triggers Oban retry in production, inline in test)
- Logs at error level when all attempts exhausted

### `CriticalEventSerializer` Tests
- `DomainEvent` survives serialize → JSON → deserialize round-trip
- `IntegrationEvent` survives serialize → JSON → deserialize round-trip
- Atom fields (`event_type`, `aggregate_type`, `source_context`) restored correctly
- Payload atom keys survive round-trip (atomized via `String.to_existing_atom/1`)
- `version` field only present for IntegrationEvent, absent for DomainEvent

### `DomainEventBus.dispatch_critical/2` Tests
- Returns per-handler results with handler identity
- Handlers still execute in priority order
- Anonymous handlers (runtime-subscribed) use `:anonymous` identity

### `EventDispatchHelper` Tests (modified)
- Critical domain event, handler succeeds → processed via `mark_processed`, no Oban job enqueued
- Critical domain event, handler fails → Oban job enqueued for failed handler only
- Critical domain event via `dispatch_or_error`, handler fails → error returned, NO Oban job
- Normal domain event, handler fails → no Oban job (unchanged behavior)

### `EventSubscriber` Tests (modified)
- Critical integration event → handler wrapped in `CriticalEventDispatcher.execute`
- Normal integration event → handler called directly (unchanged)

### Integration Event Dual Delivery Tests
- Critical integration event → PubSub broadcast AND Oban job created
- PubSub handler runs first → Oban worker skips (idempotent)
- Normal integration event → PubSub only (unchanged)

## Dependencies

No new dependencies. Oban and Ecto are already present.
