# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Klass Hero is a platform for afterschool activities, camps, and class trips management, connecting parents, instructors, and administrators.

**Tech Stack:** Elixir 1.20 + Phoenix 1.8 + LiveView 1.1 + PostgreSQL + Tailwind CSS

## Commands

```bash
# Development
mix setup                    # Complete setup (deps, database, assets)
mix phx.server               # Start dev server (localhost:4000)
iex -S mix phx.server        # Start with interactive console

# Testing
mix test                     # Run all tests
mix test path/to/test.exs    # Run specific file
mix test path/to/test.exs:42 # Run specific test at line
mix test --failed            # Re-run failed tests
mix precommit                # Pre-commit checks (compile --warnings-as-errors, format, test)

# Database
mix ecto.migrate             # Run migrations
mix ecto.reset               # Drop, create, migrate
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
│   ├── ports/           # Behavior contracts (interfaces)
│   ├── services/        # Domain logic
│   └── events/          # Domain events
├── application/
│   └── use_cases/       # Orchestration layer
└── adapters/
    └── driven/
        └── persistence/ # Ecto schemas, repos, mappers
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

See `docs/DDD_ARCHITECTURE.md` for patterns and `docs/technical-architecture.md` for context definitions.

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
- **No Claude references** - Never mention Claude in commits, PRs, or issues
- Merchant codes: set under `sumup.merchant.code` attribute

## Detailed Rules

Comprehensive guidelines live in `.claude/rules/` (auto-loaded into context). These cover LiveView, Elixir style, HEEx templates, authentication, testing, database/Ecto, MCP integration, DDD architecture, frontend, workflow, and available skills. **Do not duplicate those rules here.**

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
   bd sync
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
