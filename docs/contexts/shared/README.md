# Context: Shared

> The Shared kernel provides cross-cutting infrastructure used by all bounded contexts. It owns the domain event system (both internal and integration), file storage abstraction, pagination types, subscription tier definitions, category lists, error ID constants, and retry helpers. It has zero dependencies on other contexts — every other context depends on it.

## What This Context Owns

- **Domain Concepts:** DomainEvent (internal events), IntegrationEvent (cross-context events), PageResult (cursor pagination), ActivityGoalCalculator, Categories, SubscriptionTiers, ErrorIds
- **Data:** No database tables — purely in-memory infrastructure and pure domain types
- **Processes:** DomainEventBus (one GenServer per bounded context), EventSubscriber (one GenServer per cross-context handler), file storage adapter resolution

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Domain & Integration Event System | Active | [domain-event-system](features/domain-event-system.md) |
| Retry Helpers | Active | [retry-helpers](features/retry-helpers.md) |
| File Storage Abstraction | Active | [file-storage](features/file-storage.md) |
| Cursor-Based Pagination | Active | [cursor-pagination](features/cursor-pagination.md) |
| Configuration Registries (Tiers, Categories, Error IDs) | Active | [configuration-registries](features/configuration-registries.md) |
| Utility Helpers (Goal Calc, Ecto Helpers, Test Publishers) | Active | [utility-helpers](features/utility-helpers.md) |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| All contexts | `DomainEventBus.dispatch/2` | Synchronous in-process dispatch to registered handlers for a context's internal domain events |
| All contexts | `IntegrationEventPublishing.publish/1` | Broadcasts an integration event to PubSub for cross-context subscribers |
| All contexts | `EventPublishing.publish/1` | Broadcasts a domain event to PubSub (used by LiveView notification handlers) |
| All contexts | `EventDispatchHelper.dispatch/2` or `dispatch_or_error/2` | Fire-and-forget or error-propagating wrapper around DomainEventBus |
| All contexts | `Storage.upload/4`, `signed_url/4`, `file_exists?/3`, `delete/3` | File storage operations delegated to configured adapter |
| ProgramCatalog, Provider | `Categories.categories/0`, `valid_category?/1` | Shared category list validation |
| Family, Provider, Entitlements | `SubscriptionTiers.*` | Tier validation and defaults |
| Multiple contexts | `EctoErrorHelpers.unique_constraint_violation?/2` etc. | Changeset error introspection |
| Multiple contexts | `ErrorIds.*` | Structured log correlation IDs |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| All contexts | PubSub broadcast of `{:domain_event, %DomainEvent{}}` | Domain events on topic `"{aggregate_type}:{event_type}"` |
| All contexts | PubSub broadcast of `{:integration_event, %IntegrationEvent{}}` | Integration events on topic `"integration:{source_context}:{event_type}"` |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| **Domain Event** | An internal event within a single bounded context, dispatched synchronously via the DomainEventBus. Carries an aggregate_type and aggregate_id to identify the source entity |
| **Integration Event** | A cross-context event published via PubSub. Uses primitive-only payloads and carries a version number for schema evolution. The public contract between contexts |
| **DomainEventBus** | A per-context GenServer that maintains a registry of handler functions. Handlers execute synchronously in the caller's process (preserving test isolation). One bus per bounded context |
| **EventSubscriber** | A GenServer that subscribes to PubSub topics and dispatches incoming messages to a handler module. Used for cross-context event consumption |
| **Criticality** | A metadata flag on events — `:critical` events (e.g., GDPR) log at error level on failure; `:normal` events log at warning level |
| **Correlation ID** | An optional metadata field linking related events across contexts for distributed tracing |
| **Causation ID** | An optional metadata field identifying which event caused the current event |
| **PageResult** | A cursor-based pagination response containing items, next_cursor, has_more flag, and metadata (returned_count) |
| **PageParams** | Pagination input with limit (1-100, default 20) and optional cursor |
| **Subscription Tier** | Parent tiers: explorer (free), active (paid). Provider tiers: starter, professional, business_plus |
| **Error ID** | A structured string constant (e.g., `"program.catalog.update.stale_entry_error"`) used as a log correlation key, not shown to end users |
| **Retry with Backoff** | A single-retry strategy for transient failures (only `database_connection_error`). Permanent errors like `duplicate_resource` or `database_query_error` are not retried |

## Business Decisions

- **Zero external dependencies.** Shared depends on no other bounded context. Every other context depends on Shared. This prevents circular dependencies.
- **Two-tier event system.** Domain events are internal to a context (synchronous, in-process, rich payloads). Integration events cross context boundaries (PubSub, primitive-only payloads, versioned). A context's `PromoteIntegrationEvents` handler bridges the two.
- **DomainEventBus executes in caller's process.** The bus GenServer holds the handler registry, but handler functions execute in the calling process. This preserves process dictionary state, which is critical for test doubles that use process-dictionary-based isolation.
- **Handler priority ordering.** DomainEventBus handlers are sorted by `{priority, registration_index}` (lower priority number runs first, default 100). This ensures deterministic execution order when multiple handlers subscribe to the same event.
- **Single retry for transient errors only.** RetryHelpers retries exactly once with a configurable backoff (default 100ms). Only `database_connection_error` is considered retryable. All other errors (query errors, validation errors, duplicate resources) are permanent and fail immediately.
- **Duplicate resource is idempotent success.** RetryHelpers treats `:duplicate_resource` as `:ok`, supporting safe re-delivery of events.
- **File storage uses a single-bucket, per-object visibility model.** Public files get `public_read` ACL (direct URL access). Private files use default ACL (require signed URLs with expiration).
- **Categories are a closed set.** sports, arts, music, education, life-skills, camps, workshops. Shared owns the canonical list; ProgramCatalog and Provider validate against it.
- **Subscription tiers are atoms.** Parent: `:explorer` (default/free), `:active`. Provider: `:starter` (default), `:professional`, `:business_plus`. Shared defines them; Entitlements interprets them.
- **Pagination limit clamped to 1-100.** Out-of-range values are silently clamped, not rejected. Default limit is 20.
- **Test publishers use process dictionary isolation.** Each test process gets its own event collection, enabling concurrent test execution without shared state.

## Assumptions & Open Questions

- [NEEDS INPUT] Should integration events be persisted (event store/outbox pattern) for reliability, or is PubSub-only delivery sufficient for the current scale?
- [NEEDS INPUT] Should the retry strategy support configurable retry counts (currently hardcoded to 1 retry), or is single-retry sufficient?
- [NEEDS INPUT] Should categories be configurable at runtime (e.g., admin-managed) instead of compile-time constants?
- [NEEDS INPUT] Are additional subscription tiers planned beyond the current 2 parent + 3 provider tiers?
- [NEEDS INPUT] Should the ActivityGoalCalculator's default weekly target (5) be configurable per family or provider?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
