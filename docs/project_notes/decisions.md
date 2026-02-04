# Architectural Decisions

Record architectural decisions with context, alternatives, and trade-offs. Number sequentially.

## Format

### ADR-XXX: Decision Title (YYYY-MM-DD)

**Context:**
- Why the decision was needed

**Decision:**
- What was chosen

**Alternatives Considered:**
- Option -> Why rejected

**Consequences:**
- Benefits and trade-offs

## Entries

### ADR-001: Use Phoenix phx.gen.auth for Authentication (2025-11-01)

**Context:**
- Need user authentication for parent/provider/admin roles
- Previous custom DDD/Ports & Adapters auth (~2,100 lines) was over-engineered

**Decision:**
- Use Phoenix standard `phx.gen.auth` with scope-based pattern (~500 lines)
- Access user via `@current_scope.user`, not `@current_user`

**Alternatives Considered:**
- Custom DDD auth layer -> Rejected: too complex for the auth use case, harder to maintain
- Guardian/Pow libraries -> Rejected: phx.gen.auth is well-tested and framework-native

**Consequences:**
- Simpler, less code to maintain
- Well-tested by the Phoenix community
- Scope pattern allows future multi-tenant extensions

### ADR-002: DDD with Ports & Adapters for Domain Contexts (2025-11-15)

**Context:**
- Need clear separation between domain logic and infrastructure
- Multiple bounded contexts (Program Catalog, Enrollment, Messaging, etc.)

**Decision:**
- Use Hexagonal Architecture: domain/ports/adapters per context
- Pure Elixir structs for domain models, behaviors for ports, Ecto for persistence adapters

**Alternatives Considered:**
- Flat Phoenix contexts -> Rejected: insufficient separation for complex domain
- CQRS/Event Sourcing -> Rejected: over-engineering for current scale

**Consequences:**
- Clear boundaries between contexts
- Domain logic testable without database
- More files/directories per context (learning curve)

### ADR-003: Docker-Based Test Database (2025-11-01)

**Context:**
- Need isolated PostgreSQL for tests
- Avoid interference with development database

**Decision:**
- Docker-managed PostgreSQL container for test isolation
- `mix test.setup` / `mix test.clean` for lifecycle management

**Alternatives Considered:**
- Shared dev database with test schema -> Rejected: data interference risk
- SQLite for tests -> Rejected: PostgreSQL-specific features needed

**Consequences:**
- Complete test isolation
- Requires Docker installed
- `mix test` auto-starts container if needed

### ADR-004: Split Domain Events and Integration Events (2026-02-03)

**Context:**
- Single `DomainEvent` struct was used for both intra-context logic and cross-context PubSub communication
- This blurred bounded context boundaries — a domain event (internal concern) and an integration event (cross-context contract) have different evolution rules and audiences

**Decision:**
- Two distinct concepts: `DomainEvent` (internal to a bounded context) and `IntegrationEvent` (cross-context via PubSub)
- Domain events stay within the context that raises them; integration events are explicitly published for external consumers
- `KlassHero.Shared.IntegrationEvents` module provides the publishing contract

**Alternatives Considered:**
- Keep single `DomainEvent` for everything -> Rejected: couples internal context changes to external contracts, any rename/restructure of a domain event inadvertently breaks subscribers in other contexts
- Full event sourcing -> Rejected: unnecessary complexity at current scale (see ADR-002)

**Consequences:**
- Clearer DDD boundaries — contexts own their domain events without worrying about external consumers
- Integration events can evolve independently with explicit versioning if needed
- Slightly more ceremony when a domain action needs cross-context notification (must publish an integration event separately)
- Cross-context contracts are explicit and discoverable in one place
