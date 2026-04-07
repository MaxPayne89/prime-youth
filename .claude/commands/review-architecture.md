---
description: Review PR for DDD/Ports & Adapters architecture compliance
argument-hint: "[pr-number]"
---

Review the current PR for DDD/Ports & Adapters architecture compliance.

## Setup

1. **Resolve the PR number:**
   - If `$ARGUMENTS` is provided and is a number, use it directly
   - Otherwise run `gh pr view --json number --jq '.number'` to auto-detect from the current branch
2. **Fetch the diff:** `gh pr diff <number>`
3. **Fetch PR context:** `gh pr view <number> --json title,body,headRefName`
4. **Read project architecture rules:** `.claude/rules/domain-architecture.md`

## Review

Analyze the diff against each focus area below. For each area report one of:
- `✅ PASS` — no violations found
- `⚠️ WARNING` — potential issue worth discussing (not a hard breach)
- `❌ VIOLATION` — clear architecture breach — cite `file:line` and describe the fix

### 1. Bounded Context Boundaries
- Domain logic stays within its bounded context (no cross-context imports of internal modules)
- Contexts communicate only through public facade functions or domain events
- Shared kernel (`shared/`) contains only truly shared concepts

### 2. Ports & Adapters Layering
- **Domain layer** (`domain/models/`, `domain/ports/`, `domain/services/`, `domain/events/`): Pure Elixir structs and behaviors, no Ecto/Phoenix/infrastructure dependencies
- **Application layer** (`application/use_cases/`): Orchestrates domain logic, depends only on ports (not concrete adapters)
- **Adapter layer** (`adapters/driven/persistence/`): Ecto schemas, repo implementations, mappers — implements port behaviors
- **Web layer** (`lib/klass_hero_web/`): LiveViews, components, presenters — drives use cases, never touches domain internals directly

### 3. Dependency Direction
- Dependencies point inward: Web → Application → Domain
- Domain never depends on Application or Adapters
- Use cases depend on port behaviors, not concrete adapter modules
- Configuration-based dependency injection via module attributes (e.g., `@repository Application.compile_env!(...)`)

### 4. Domain Model Integrity
- Domain models are plain Elixir structs (not Ecto schemas)
- Value objects enforce their invariants at creation time
- No Ecto changesets or Repo calls in domain logic

### 5. Event Classification
Assess whether each event uses the correct type(s). An event can be multiple kinds simultaneously:
- **Domain Events**: Concern only the originating bounded context (internal state changes, invariant enforcement). Stay within the context boundary.
- **Integration Events**: Must propagate past the context boundary to another bounded context (e.g., triggering a workflow in Enrollment when a Program is created in Program Catalog).
- **UI Events**: Must be communicated to the LiveView layer, so they also cross the context boundary (e.g., notifying the provider dashboard of a new enrollment).
- Flag events that are misclassified (e.g., an event that crosses contexts but is only typed as a domain event, or a UI-relevant event with no LiveView propagation path).
- Verify that integration/UI events have proper publishing infrastructure (event bus, PubSub) while domain events can remain internal.

### 6. Naming & Structure Conventions
- Context directory structure follows `context/{domain,application,adapters}/` pattern
- Port modules named `ForDoingSomething` (e.g., `ForStoringPrograms`)
- Use case modules are single-purpose with an `execute/1` function
- Ecto schemas live only in `adapters/driven/persistence/`
- Mappers convert between domain models and Ecto schemas
- Driving adapters (event handlers, Oban workers) live under `adapters/driving/`
- Driven adapters (repositories, external APIs) live under `adapters/driven/`

### 7. Web Layer Patterns
- LiveViews use `@current_scope` (never `@current_user`)
- Presenters transform domain data for templates (no domain logic in templates)
- Forms always use `to_form/2` assigns, never raw changesets
- Streams used for collections, not list assigns

### 8. Anti-Patterns to Flag
- Direct Repo calls from LiveViews or use cases
- Ecto schemas used as domain models
- Cross-context database joins
- Business logic in controllers/LiveViews
- Infrastructure concerns leaking into domain layer

## Output Format

```
## Architecture Review — PR #<number>: <title>

### 1. Bounded Context Boundaries — ✅ PASS / ⚠️ WARNING / ❌ VIOLATION
<findings or "No issues found.">

### 2. Ports & Adapters Layering — ✅ PASS / ...
...

[repeat for all 8 areas]

---
## Summary

**Violations (must fix):**
- <list or "None">

**Warnings (worth discussing):**
- <list or "None">

**Overall:** ✅ Architecture compliant / ❌ Requires changes before merge
```
