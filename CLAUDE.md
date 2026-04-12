# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Klass Hero is a platform for afterschool activities, camps, and class trips management, connecting parents, instructors, and administrators.

**Tech Stack:** Elixir 1.20 + Phoenix 1.8 + LiveView 1.1 + PostgreSQL + Tailwind CSS + Oban + Backpex

## Commands

```bash
# Development
mix setup                    # Complete setup (deps, database, seeds, assets)
mix phx.server               # Start dev server (localhost:4000)
iex -S mix phx.server        # Start with interactive console

# Testing
mix test                     # Run all tests
mix test path/to/test.exs    # Run specific file
mix test path/to/test.exs:42 # Run specific test at line
mix test --failed            # Re-run failed tests
mix test.e2e                 # Run end-to-end tests (Wallaby/Playwright)

# Quality
mix precommit                # Full pre-commit: compile --warnings-as-errors, deps.unlock --unused, format, lint_typography, test
mix credo --strict           # Elixir linting (runs in CI)
mix lint_typography          # Check font/typography usage in templates

# Database
mix ecto.migrate             # Run migrations
mix ecto.reset               # Drop, create, migrate
mix run priv/repo/seeds.exs  # Seed development data
mix test.setup               # Setup Docker test database
mix test.clean               # Clean test database (removes volumes)

# Documentation lookup
mix usage_rules.docs Enum.zip           # Get docs for function/module
mix usage_rules.search_docs "query"     # Search across all packages
```

## Architecture

### Bounded Contexts (DDD + Ports & Adapters)

Each context under `lib/klass_hero/` follows this internal structure:

```
context/
├── domain/
│   ├── models/          # Pure Elixir structs (entities, value objects)
│   ├── ports/           # Driven port contracts (flat = driven by convention)
│   │   └── driving/     # Driving port contracts (only in shared context)
│   ├── services/        # Domain logic
│   └── events/          # Domain events
├── application/
│   └── use_cases/       # Orchestration layer
└── adapters/
    ├── driven/          # Outbound adapters (persistence, ACL, notifications, infra)
    │   └── persistence/ # Ecto schemas, repos, mappers
    └── driving/         # Inbound adapters (event handlers, workers)
        ├── events/      # Domain & integration event handlers
        └── workers/     # Oban background job workers
```

**Active contexts:**

- **Accounts** (`accounts/`) - User auth via `phx.gen.auth`, scopes, roles, tokens
- **Family** (`family/`) - Parent profiles, children management, consents, referral codes
- **Provider** (`provider/`) - Provider profiles, staff members, verification documents
- **Program Catalog** (`program_catalog/`) - Program discovery, filtering, pricing, categories
- **Enrollment** (`enrollment/`) - Bookings, fee calculations, subscription tiers
- **Entitlements** (`entitlements.ex`) - Pure domain service for subscription tier authorization (cross-context, no DB)
- **Messaging** (`messaging/`) - Conversations, messages, participants, retention policies
- **Participation** (`participation/`) - Session tracking, check-in/out, attendance rosters
- **Shared** (`shared/`) - Event publishing, Ecto helpers, pagination, domain events

See `.claude/rules/domain-architecture.md` for patterns and `docs/contexts/` for per-context documentation (living docs with feature specs, context canvases, and cross-context flows — use `/doc` to regenerate).

### Dependency Injection (Port Wiring)

Each bounded context's port-to-adapter bindings are configured in `config/config.exs` using a naming convention that mirrors the port behaviour names:

```elixir
# config/config.exs — each context gets a key with port → adapter mappings
config :klass_hero, :enrollment,
  for_managing_enrollments: EnrollmentRepository,
  for_resolving_participant_details: ParticipantDetailsACL,
  for_sending_invite_emails: InviteEmailNotifier

# config/test.exs can override with test doubles
```

When adding a new port: define the behaviour in `domain/ports/`, implement the adapter in `adapters/driven/`, then wire it in `config/config.exs` under the context's key.

### Event System (Two-Tier)

- **Domain events** (non-critical): Published via PubSub (`PubSubEventPublisher`). Used for real-time UI updates and non-essential side effects.
- **Integration events** (critical): Routed through `critical_event_handlers` registry in `config/config.exs` to Oban-backed handlers for durable, at-least-once delivery. Used for cross-context workflows (e.g., `invite_claimed`, `user_registered`).

### Feature Flags

Uses `FunWithFlags` for runtime feature toggling. Adapter is configurable per environment (`StubFeatureFlagsAdapter` in test).

### Authentication & Role-Based Routing

Uses Phoenix `phx.gen.auth` with scope-based pattern:

- **Always use `@current_scope`** (not `@current_user`)
- Access user via `@current_scope.user`

Router defines 5 `live_session` scopes with role-based access:

- `:public` - Optional auth (home, programs, about, contact, legal pages)
- `:authenticated` - Auth required (dashboard, settings, booking, messages)
- `:require_provider` - Provider role (`/provider/*` routes)
- `:require_parent` - Parent role (`/parent/*` routes)
- `:require_authenticated_user` - Auth pages (user settings, email confirmation)

### Web Layer Patterns

**Components** organized by domain in `lib/klass_hero_web/components/` (ui, composite, program, booking, provider, participation, messaging, review, theme).

**Presenters** in `lib/klass_hero_web/presenters/` transform domain models for templates.

**Internationalization:** Gettext with English (`en`) and German (`de`) in `priv/gettext/`.

## MCP Integration

**Tidewave MCP** (ALWAYS prefer over bash for Phoenix work): `project_eval`, `get_docs`, `execute_sql_query`, `get_logs`, `get_source_location`, `get_ecto_schemas`.

If Tidewave unavailable: Alert user immediately - indicates Phoenix server not running or MCP issue.

**Playwright MCP** for UI testing: test LiveView interactions, verify mobile-responsive designs.

## Project Constraints

- **Mobile-first design** - Design for mobile before desktop
- **Warnings as errors** - All warnings must be resolved before commit
- **Tests before commit** - If tests fail, fix before proceeding — never commit with failing tests
- **No Claude references** - Never mention Claude in commits, PRs, or issues
- Merchant codes: set under `sumup.merchant.code` attribute

## Git Conventions

Use semantic commit messages: `type: description`

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`

Examples: `feat: add staff invitation flow`, `fix: correct enrollment fee calculation`, `ci: split test workflow into parallel jobs`

## CI Pipeline

These checks run automatically on every PR — don't manually recheck what CI catches:

| Check | Catches |
|---|---|
| `mix compile --warnings-as-errors` | Unused vars/imports, deprecations, Boundary violations |
| `mix format --check-formatted` | Formatting issues |
| `mix credo --min-priority=high` | Style violations, code smells |
| `mix lint_typography` | Font/typography usage violations |
| `mix test` | Functional regressions (full suite with PostgreSQL) |
| Sobelow | Common Phoenix security vulnerabilities |
| `mix deps.audit` | Known dependency vulnerabilities |
| Conventional commits | PR title format validation |

## Ecto Anti-Patterns

- **Never** use `Multi.run` for side-effects — `Multi.run` is for operations that need to be part of the transaction
- **Never** read data outside a `Multi` transaction and use it inside — fetch within the Multi to avoid race conditions

## PR Review Comments

When addressing PR review comments, follow this workflow:

1. Fetch all comments on the PR
2. Triage: classify as actionable fix, style nit, or dismissible bot noise
3. Confirm with user before dismissing any comments
4. Apply fixes for actionable items
5. Run `mix precommit`, then commit and push

## Detailed Rules

Comprehensive guidelines live in `.claude/rules/` (auto-loaded into context). These cover LiveView, Elixir style, HEEx templates, authentication, testing, database/Ecto, MCP integration, DDD architecture, frontend, workflow, available skills, and behavioral guidelines. **Do not duplicate those rules here.**

<!-- usage-rules-start -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

[usage_rules usage rules](deps/usage_rules/usage-rules.md)
<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- usage-rules-end -->

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
