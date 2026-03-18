# Copilot Code Review Instructions

For full project conventions, see [CLAUDE.md](../CLAUDE.md).

## Review Philosophy

- Only comment when you have **high confidence (>80%)** that an issue exists.
- One sentence per comment when possible — be concise.
- Every comment must be **actionable**: state the problem, explain why it matters, suggest a concrete fix.
- If you're not sure something is a problem, **say nothing**.

## Priority Areas

### Security & Safety

- SQL injection via raw `Ecto.Adapters.SQL.query/3` or string-interpolated fragments
- Missing authorization checks — this project uses scope-based auth (`@current_scope`), never `@current_user` directly
- Credential or secret exposure in code, configs, or templates
- Unsafe `String.to_atom/1` on user input (memory leak / atom table exhaustion)
- Missing input validation at system boundaries (controller params, external API responses)
- Ecto fields set via user-controlled `cast/3` that should be set programmatically (e.g., `user_id`)

### Correctness

- Pattern match failures that would crash at runtime
- Race conditions in concurrent code (GenServer state, Oban jobs)
- `Ecto.Multi` misuse: side-effects in `Multi.run/5`, or reading data outside a Multi and using it inside (stale reads)
- Missing Ecto preloads that cause N+1 queries or `Ecto.Association.NotLoaded` errors
- Incorrect `with` chain error handling — unmatched error clauses falling through silently
- LiveView stream misuse: filtering streams with `Enum` (streams aren't enumerable), using deprecated `phx-update="append"`
- Using `changeset[:field]` map access on structs — must use `Ecto.Changeset.get_field/2`

### Architecture & Conventions

- **Bounded context violations**: one context directly calling another context's internal modules (adapters, schemas) instead of going through the public API
- **Port/adapter contract breaks**: adapter not implementing all callbacks defined by its port behaviour
- **Domain logic in the web layer**: business rules in LiveView `handle_event` instead of use cases or domain services
- **Event publishing patterns**: domain events should flow through the Shared event infrastructure, not ad-hoc PubSub calls
- **Ecto schema vs domain model**: Ecto schemas belong in `adapters/driven/persistence/`, domain models in `domain/models/`

## Project-Specific Context

- **Stack**: Elixir 1.20, Phoenix 1.8, LiveView 1.1, PostgreSQL, Oban, Backpex
- **Architecture**: DDD with Ports & Adapters (Hexagonal), event-driven, moving toward CQRS and event sourcing
- **Bounded contexts**: Accounts, Family, Provider, Program Catalog, Enrollment, Entitlements, Messaging, Participation, Shared
- **Auth pattern**: `phx.gen.auth` with scopes — always use `@current_scope`, access user via `@current_scope.user`
- **Error handling**: `{:ok, result}` / `{:error, reason}` tuples, `with` chains — no exceptions for control flow
- **LiveView collections**: always use streams (`stream/3`), never assign raw lists
- **Design**: mobile-first mandatory — every UI element designed for mobile before desktop

## CI Pipeline Coverage — Don't Duplicate These

The following checks run automatically on every PR. Do **not** flag issues already caught by these:

| Check | What it catches |
|---|---|
| `mix compile --warnings-as-errors` | Unused variables, imports, unreachable code, deprecations |
| `mix format --check-formatted` | All formatting issues |
| `mix credo --min-priority=high` | Style violations, code smells, complexity |
| `mix lint_typography` | Font/typography usage violations |
| `mix test` | Functional regressions (full suite with PostgreSQL) |
| Sobelow security scan | Common Phoenix security vulnerabilities (XSS, CSRF, SQL injection patterns) |
| Conventional commits check | PR title format validation |

## Skip These — Low-Value Comments

- Code formatting (covered by `mix format`)
- Credo-level style warnings (covered by CI)
- Typography/font usage (covered by `mix lint_typography`)
- Variable naming nitpicks
- Refactoring suggestions that don't fix a bug or prevent a real problem
- Missing `@moduledoc`, `@doc`, or typespecs on unchanged code
- Suggesting dependencies or libraries the project doesn't use
- Comments about test coverage on unchanged code

## Response Format

When you do comment, follow this structure:

1. **Problem**: State what's wrong in one sentence
2. **Why it matters**: Security risk, runtime crash, data inconsistency, architecture violation
3. **Suggested fix**: Show concrete code or describe the specific change

## When to Stay Silent

- If you're less than 80% confident → say nothing
- If it's a style preference not backed by a bug → say nothing
- If CI already catches it → say nothing
- If the code works correctly and follows project conventions → say nothing
