---
name: boundary-checker
description: >-
  Check semantic boundary violations that the Boundary library cannot detect
  at compile time. Finds use cases calling cross-context adapters directly,
  schemas leaking across context boundaries, and port contracts being bypassed
  via direct Repo calls. Run as a subagent for deep boundary analysis.
---

# Boundary Checker

Detect semantic boundary violations that compile-time tools miss.

**Type:** Deep analysis. Scan code patterns across the entire codebase.

---

## Context

The `boundary` library enforces module-level dependency rules at compile time via
`use Boundary` declarations. However, it CANNOT detect these semantic violations:

1. A use case that calls another context's driven adapter if that adapter was pragmatically exported
2. Ecto schemas from one context being queried or joined in another context's repository
3. Direct `KlassHero.Repo` calls in use cases or domain code, bypassing port abstractions
4. Integration event handlers reaching into another context's internals instead of using the facade API

This subagent fills those gaps.

---

## Check 1: Use Cases Must Not Call Cross-Context Adapters

**Rule:** Use cases (`application/use_cases/`) must only call:
- Ports via DI module attributes (`@repo`, `@resolver`, etc.)
- Their own context's facade module
- Other contexts' facade modules (e.g., `KlassHero.Messaging.send_message/3`)
- Shared infrastructure (`DomainEventBus`, `FeatureFlags`, etc.)

**Violation pattern:** A use case in context A directly aliases or calls a module from context B's `adapters/` directory.

**How to verify:**
1. For each use case file, extract all `alias` and module references
2. Determine each referenced module's owning context
3. If a module belongs to another context's `adapters/` namespace, flag it
4. Exception: Shared context adapters that are explicitly exported (e.g., `Tracing`, `RepositoryHelpers`)

**Example violation:**
```elixir
# In messaging/application/use_cases/send_message.ex
# BAD: directly calling enrollment's repository
alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository
EnrollmentRepository.get_by_id(id)
```

**Correct pattern:**
```elixir
# Use a port + ACL adapter within the messaging context
@enrollment_resolver Application.compile_env!(:klass_hero, [:messaging, :for_querying_enrollments])
@enrollment_resolver.get_enrollments_for_program(program_id)
```

## Check 2: No Cross-Context Schema Access in Repositories

**Rule:** A repository in context A must not query, join, or reference Ecto schemas from context B — even indirectly via `from(e in OtherContextSchema)`.

**Exceptions:**
- `KlassHero.Accounts.Adapters.Driven.Persistence.Schemas.UserSchema` — commonly used for `belongs_to` associations (known pragmatic exception)
- Schemas explicitly listed in another context's `exports:` Boundary config

**How to verify:**
1. For each repository file (`adapters/driven/persistence/repositories/*.ex`)
2. Extract all schema modules referenced in queries (`from(x in Schema)`, `join`, `preload`, etc.)
3. Determine each schema's owning context
4. Flag references to schemas from other contexts (except the allowed exceptions)

**Example violation:**
```elixir
# In messaging/adapters/driven/persistence/repositories/conversation_repository.ex
# BAD: directly querying enrollment schema
from(e in KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema,
  where: e.program_id == ^program_id)
```

## Check 3: Port Contracts Must Not Be Bypassed

**Rule:** Use cases and domain services must NEVER call `KlassHero.Repo` directly. All database access goes through port-based repository adapters injected via DI.

**How to verify:**
1. Grep for `KlassHero.Repo.` or `alias KlassHero.Repo` in:
   - `application/use_cases/`
   - `domain/models/`
   - `domain/services/`
   - `domain/events/`
2. Flag every occurrence — there should be ZERO matches in these directories
3. `KlassHero.Repo` calls are ONLY allowed in:
   - `adapters/driven/persistence/repositories/`
   - `adapters/driven/persistence/queries/`
   - `adapters/driven/acl/`
   - Shared infrastructure helpers (`RepositoryHelpers`, etc.)

**Example violation:**
```elixir
# In messaging/application/use_cases/send_message.ex
# BAD: direct Repo call bypassing the port
KlassHero.Repo.insert(%MessageSchema{content: content})
```

## Check 4: Event Handlers Must Use Facade APIs

**Rule:** Integration event handlers in `adapters/driving/events/` must call the target context's public facade API — not internal use cases, repositories, or adapters.

**How to verify:**
1. For each integration event handler
2. Extract all module calls that reach into another context
3. Calls should be to `KlassHero.{Context}.function_name()` (facade)
4. Flag calls to `KlassHero.{Context}.Application.UseCases.*` or `KlassHero.{Context}.Adapters.*`
5. Within-context event handlers MAY call their own use cases directly

**Example violation:**
```elixir
# In messaging/adapters/driving/events/staff_assignment_handler.ex
# BAD: calling another context's use case directly
KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram.execute(attrs)
```

**Correct pattern:**
```elixir
# Call the facade
KlassHero.Provider.assign_staff_to_program(attrs)
```

## Check 5: Domain Layer Isolation

**Rule:** The domain layer (`domain/models/`, `domain/services/`, `domain/events/`) must have ZERO dependencies on:
- Ecto (`Ecto.Changeset`, `Ecto.Schema`, `Ecto.Query`)
- Phoenix (`Phoenix.*`)
- Infrastructure (`KlassHero.Repo`, `Oban`, `Jason`)
- Other contexts' internals

**How to verify:**
1. For each file in `domain/models/`, `domain/services/`, `domain/events/`
2. Extract all `alias`, `import`, `use`, and `require` declarations
3. Check each referenced module against the allow-list:
   - Own context's domain modules
   - Elixir/Erlang standard library
   - `KlassHero.Shared.Domain.*` (shared domain types)
   - `Logger` (acceptable for domain services)
4. Flag any infrastructure or cross-context dependency

## Check 6: ACL Adapter Correctness

**Rule:** Anti-Corruption Layer adapters (`adapters/driven/acl/`) must:
- Implement a port behaviour from their own context
- Call the target context's PUBLIC facade API (not internal modules)
- Map external data to their own context's domain types

**How to verify:**
1. For each ACL adapter file
2. Verify it declares `@behaviour` for a port in its own context
3. Check all external calls go through facade modules (e.g., `KlassHero.Family.get_child/1`)
4. Flag direct calls to another context's repositories, schemas, or use cases

---

## Output Format

```
# Boundary Analysis Report

## Summary
- Checks passed: N/6
- Semantic violations found: N
- Context pairs with violations: [list]

## Violations

### [CHECK_NAME] — [severity: critical|warning]
- **Source:** path/to/file.ex:line
- **Violates:** [which boundary rule]
- **Details:** [module X in context A references module Y in context B]
- **Impact:** [what breaks: encapsulation, testability, etc.]
- **Fix:** [specific refactoring needed]

## Cross-Context Dependency Map
[visual or tabular summary of actual cross-context calls found]
```

---

## Rules

- Scan the ENTIRE codebase, not just changed files — boundary violations can be pre-existing
- The Accounts.User schema reference is a KNOWN exception — do not flag it
- Shared context exports are accessible to all — check `lib/klass_hero/shared.ex` exports list
- Boundary `exports:` are pragmatic exceptions — note them but flag as warnings, not errors
- ACL adapters are the CORRECT way to access cross-context data — verify they exist where needed
- If a violation is found, suggest the correct pattern (port + ACL adapter, or facade call)
- Critical severity: bypassing ports, direct Repo in domain/use-cases
- Warning severity: cross-context schema in belongs_to, missing ACL where one should exist
