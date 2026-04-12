# Domain Architecture

The project follows Domain-Driven Design with Ports & Adapters architecture (Hexagonal Architecture).

## Bounded Contexts

1. **Program Catalog Context** - Program discovery, details, availability
2. **Enrollment Context** - Enrollment process from selection to payment
3. **Family Context** - Parent profiles, children management, consents, referral codes, GDPR family data
4. **Provider Context** - Provider profiles, staff members, verification documents
5. **Progress Tracking Context** - Child progress and achievements
6. **Review & Rating Context** - Program reviews and feedback

## Architecture Documentation

**Start here for architectural guidance:**

- `docs/contexts/` - Per-bounded-context documentation (purpose, features, communication patterns)
- Existing context implementations under `lib/klass_hero/` - Follow established patterns

## Authentication Note

The authentication system uses Phoenix's standard `phx.gen.auth` for simplicity and maintainability. For future bounded contexts (Program Catalog, Enrollment, Family, Provider, etc.), the DDD/Ports & Adapters architecture documented in the above files will be followed.

## Port & Adapter Directionality

Ports and adapters are split by **direction of control flow**:

### Classification Rule

> If Oban or the event bus triggers it, it's **driving**. If the application calls it outward, it's **driven**.

### Ports (`domain/ports/`)

- **Driven ports** (flat in `ports/`): Contracts the application calls outward — persistence, ACL queries, publishing, sending. Named `for_storing_*`, `for_managing_*`, `for_resolving_*`, `for_publishing_*`, etc.
- **Driving ports** (in `ports/driving/`, shared context only): Contracts that external stimuli implement to drive the application. Named `for_handling_*`. Currently only `ForHandlingEvents` and `ForHandlingIntegrationEvents`.

### Adapters

- **Driven adapters** (`adapters/driven/`): Outbound implementations — Ecto repositories, ACL adapters, email senders, event publishing infrastructure, file storage.
- **Driving adapters** (`adapters/driving/`): Inbound entry points — event handlers (domain and integration), Oban workers. These receive external triggers and drive use cases inward.

### Shared Context Infrastructure

The shared context's `adapters/driven/events/` directory contains event **infrastructure** (publishers, subscriber, registry, serializers, retry helpers, test doubles) — these are driven because the application calls them outward. Individual context event **handlers** live under their own `adapters/driving/events/`.

## CQRS Direction

The codebase is moving toward Command Query Responsibility Segregation:

- New use cases go under `application/commands/` or `application/queries/`
- New ports should separate read contracts (`ForQuerying*`, `ForListing*`) from write contracts (`ForStoring*`, `ForCreating*`, `ForUpdating*`)
- Existing mixed `ForManaging*` ports will be split incrementally
- `ForResolving*` ports (ACL) are already read-only — no change needed

**Naming conventions:**
- Commands: `Application.Commands.CreateEnrollment` — state-changing operations
- Queries: `Application.Queries.ListParentEnrollments` — read-only operations
- Mixed use cases that read then write: classify as Commands
- Utility/shared modules stay at `application/` level (not in commands/ or queries/)

**Existing CQRS infrastructure:**
- Program Catalog and Messaging have event-driven projections with denormalized read tables
- Projection GenServers in `adapters/driven/projections/` maintain read models
- Read model DTOs in `domain/read_models/` are display-optimized structs with no business logic

## Key Patterns for Future Contexts

- Domain entities and value objects (pure Elixir structs)
- Repository ports and Ecto adapters
- Use case orchestration patterns
- Phoenix web adapters (driving adapters)
- Event handler and worker adapters (driving adapters under `adapters/driving/`)
- Configuration and dependency injection
