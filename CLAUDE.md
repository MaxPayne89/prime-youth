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
- `:require_provider` - Provider role (`/provider/*` routes: sessions, participation, broadcast)
- `:require_parent` - Parent role (`/parent/*` routes: participation history)
- `:require_authenticated_user` - Auth pages (user settings, email confirmation)

### Web Layer Patterns

**Components** organized by domain in `lib/klass_hero_web/components/`:
`ui_components.ex`, `composite_components.ex`, `program_components.ex`, `booking_components.ex`, `provider_components.ex`, `participation_components.ex`, `messaging_components.ex`, `review_components.ex`, `theme.ex`

**Presenters** in `lib/klass_hero_web/presenters/` transform domain models for templates (child, program, provider).

**Internationalization:** Gettext with English (`en`) and German (`de`) in `priv/gettext/`.

## Critical Patterns

### LiveView Forms (Most Common Source of Errors)

```elixir
# LiveView: ALWAYS assign form via to_form/2
def mount(_params, _session, socket) do
  changeset = MySchema.changeset(%MySchema{}, %{})
  {:ok, assign(socket, form: to_form(changeset))}
end
```

```heex
<%!-- Template: ALWAYS use @form, NEVER @changeset --%>
<.form for={@form} id="my-form" phx-submit="save">
  <.input field={@form[:name]} type="text" />
</.form>
```

### LiveView Streams (Required for Collections)

```elixir
# Mount: initialize stream
{:ok, stream(socket, :items, list_items())}

# Filter/reset: refetch and reset
socket |> stream(:items, list_items(filter), reset: true)
```

```heex
<%!-- Template: require phx-update="stream" and id on both parent and children --%>
<div id="items" phx-update="stream">
  <div :for={{id, item} <- @streams.items} id={id}>{item.name}</div>
</div>
```

### HEEx Template Syntax

```heex
<%!-- Attributes: use {...} --%>
<div id={@id} class={["base", @active && "active"]}>

<%!-- Values in body: use {...} --%>
{@user.name}

<%!-- Block constructs (if/for/cond): use <%= %> --%>
<%= if @show do %>content<% end %>
<%= for item <- @items do %>{item}<% end %>

<%!-- Conditional classes: MUST use list syntax --%>
<div class={["px-2", @flag && "py-5", if(@cond, do: "red", else: "blue")]}>
```

### Elixir Gotchas

```elixir
# Variable rebinding: MUST capture block result
socket = if connected?(socket), do: assign(socket, :foo, bar), else: socket

# List access: NO bracket syntax - use Enum.at/2
Enum.at(list, 0)  # NOT list[0]

# Struct access: NO bracket syntax - use dot notation
my_struct.field   # NOT my_struct[:field]

# Changeset field access: use get_field/2
Ecto.Changeset.get_field(changeset, :field)

# Multiple conditionals: NO else if - use cond
cond do
  condition1 -> result1
  condition2 -> result2
  true -> default
end
```

### Ecto Guidelines

```elixir
# Always preload associations accessed in templates
Repo.all(Message) |> Repo.preload(:user)

# Schema fields: use :string even for text columns
field :description, :string  # NOT :text

# Programmatic fields (user_id): NEVER in cast - set explicitly
|> put_assoc(:user, user)  # NOT cast(attrs, [:user_id])

# validate_number does NOT support :allow_nil (it's the default behavior)
|> validate_number(:price, greater_than: 0)
```

### Router Scope Aliases

```elixir
# The scope provides the alias - DON'T add your own
scope "/admin", KlassHeroWeb.Admin do
  live "/users", UserLive  # Points to KlassHeroWeb.Admin.UserLive
end
```

## MCP Integration

**Tidewave MCP** (ALWAYS prefer over bash for Phoenix work):

- `project_eval` - Evaluate Elixir code in running app
- `get_docs` - Get module/function documentation
- `execute_sql_query` - Run SQL queries
- `get_logs` - Check application logs
- `get_source_location` - Find code locations
- `get_ecto_schemas` - Inspect schemas

If Tidewave unavailable: Alert user immediately - indicates Phoenix server not running or MCP issue.

**Playwright MCP** (for UI testing):

- Test LiveView interactions and flows
- Verify mobile-responsive designs

## Project Constraints

- **Mobile-first design** - Design for mobile before desktop
- **Warnings as errors** - All warnings must be resolved before commit
- **No Claude references** - Never mention Claude in commits, PRs, or issues
- Merchant codes: set under `sumup.merchant.code` attribute

## Detailed Rules

For comprehensive guidelines, see `.claude/rules/`:

- `liveview.md` - Streams, forms, testing patterns
- `elixir-style.md` - Elixir idioms, OTP patterns
- `phoenix.md` - HEEx templates, router patterns
- `authentication.md` - Scope pattern, layouts
- `testing.md` - Test patterns, Docker setup
- `database.md` - Ecto patterns, documentation lookup
- `mcp-integration.md` - Tidewave and Playwright usage
- `domain-architecture.md` - DDD, Ports & Adapters patterns
- `frontend.md` - Component organization, mobile-first design
- `workflow.md` - GitHub branching, pre-commit checklist
- `skills.md` - Available specialized skills

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
