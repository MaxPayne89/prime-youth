# Admin Account Overview

**Issue:** #367 — Add Account type and Subscription columns to admin dashboard
**Date:** 2026-03-12
**Approach:** Rename and evolve existing UserLive Backpex resource into AccountLive

## Context

The admin dashboard has a "Users" Backpex resource showing email, name, is_admin toggle, and created_at. Its only real value is toggling the admin flag on other users. This feature replaces it with a richer "Accounts" overview that shows each user's roles and subscription tiers at a glance.

The separate `/admin/providers` resource remains unchanged for detailed provider management (verification, tier editing, event publishing).

## Ubiquitous Language

- **User** — the authentication identity (email + password)
- **Parent** — a role, determined by the existence of a parent profile
- **Provider** — a role, determined by the existence of a provider profile
- **Admin** — a privilege flag on the user record (`is_admin`)
- A user can hold all three simultaneously

Roles are not stored as a list on the user — they are resolved by checking whether the corresponding profile exists. The `Accounts.Scope` module encodes this pattern.

## Schema Changes

Add two `has_one` associations to the User Ecto schema (`lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`).

Required aliases (cross-context references, deliberately scoped to read-only admin display):

```elixir
alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
```

Associations:

```elixir
has_one :parent_profile, ParentProfileSchema, foreign_key: :identity_id
has_one :provider_profile, ProviderProfileSchema, foreign_key: :identity_id
```

**Architectural note:** This creates a cross-context reference (Accounts → Family/Provider schemas). This is a deliberate trade-off: the User Ecto schema already lives in the persistence adapter layer (not the domain model), and the `has_one` is read-only — used only for Backpex preloading in the admin dashboard. The pure domain model `Accounts.Domain.Models.User` is untouched.

- Read-only from the admin perspective — no writes go through these associations
- `admin_update_changeset` now only casts `:is_admin`. Admins can no longer edit user names via this flow; other name-edit use cases rely on a separate changeset, and the read-only behavior in Backpex is enforced via field configuration.
- No changes to ParentProfileSchema or ProviderProfileSchema
- No migrations needed

## AccountLive Backpex Resource

Rename `user_live.ex` → `account_live.ex`, module `UserLive` → `AccountLive`.

### Configuration

- `singular_name` → `"Account"`, `plural_name` → `"Accounts"`
- `item_query` in `adapter_config` preloads `:parent_profile` and `:provider_profile` for index/show actions. The `:edit` action intentionally skips this preload as an optimization because the edit form does not use these associations and `can?/3` only depends on the user record itself.
- `can?/3` unchanged — no self-edit, no create/delete

### Fields (in order)

1. **Email** — text, searchable, orderable, readonly
2. **Name** — text, searchable, orderable, readonly
3. **Roles** — text with custom `render`, read-only, index/show only. Displays colored badges based on profile existence and admin flag. **Not orderable, not searchable** — no backing database column.
4. **Subscription** — text with custom `render`, read-only, index/show only. Displays tier badges from preloaded profiles. **Not orderable, not searchable** — no backing database column.
5. **Admin** — boolean, orderable, edit only (`only: [:edit]`). The sole editable field.
6. **Created At** — datetime, orderable, index/show only

Name becomes readonly (was editable in UserLive). Admin toggle moves to edit-only (not shown as a column on index, since it's absorbed into the Roles badges).

### Render Function Access Pattern

The Roles and Subscription fields have no backing database column, so `@value` will be `nil`. The custom `render` functions must use `@item` (the full preloaded record) instead:

- Roles render: checks `@item.parent_profile`, `@item.provider_profile`, `@item.is_admin`
- Subscription render: checks `@item.parent_profile.subscription_tier`, `@item.provider_profile.subscription_tier`

This follows Backpex convention — `@item` is available in render assigns alongside `@value`.

### Roles Badge Rendering

| Condition                      | Badge    | Tailwind classes |
| ------------------------------ | -------- | ---------------- |
| `parent_profile != nil`        | Parent   | `bg-blue-100 text-blue-700` |
| `provider_profile != nil`      | Provider | `bg-purple-100 text-purple-700` |
| `is_admin == true`             | Admin    | `bg-red-100 text-red-700` |
| None of the above              | User     | `bg-gray-100 text-gray-700` |

Multiple badges shown simultaneously for users with multiple roles.

### Subscription Badge Rendering

| Tier                           | Badge        | Tailwind classes |
| ------------------------------ | ------------ | ---------------- |
| Parent: explorer               | Explorer     | `bg-gray-100 text-gray-700` |
| Parent: active                 | Active       | `bg-green-100 text-green-700` |
| Provider: starter              | Starter      | `bg-gray-100 text-gray-700` |
| Provider: professional         | Professional | `bg-blue-100 text-blue-700` |
| Provider: business_plus        | Business+    | `bg-amber-100 text-amber-700` |
| No profiles                    | —            | — |

Badge base classes (same pattern as BookingLive status badges): `inline-flex items-center rounded-full px-2 py-1 text-xs font-medium`.

## Route Changes

Router (`lib/klass_hero_web/router.ex`):

```elixir
# Before
live_resources("/users", UserLive, only: [:index, :show, :edit])

# After
live_resources("/accounts", AccountLive, only: [:index, :show, :edit])
```

## Navigation Changes

| File | Change |
| --- | --- |
| `admin.html.heex` sidebar | `/admin/users` → `/admin/accounts`, label "Users" → "Accounts" |
| `app.html.heex` (2 links) | `/admin/users` → `/admin/accounts` |

Icon (`hero-users`) stays — still appropriate for an accounts view.

## Test Changes

Rename `user_live_test.exs` → `account_live_test.exs`, module `UserLiveTest` → `AccountLiveTest`.

### Tests to update

- All `/admin/users` routes → `/admin/accounts`
- `html =~ "Users"` → `html =~ "Accounts"`

### Tests to remove

- Name editing tests (blank, too short, update) — name is now readonly
- Edit tests that submit name changes

### Tests to keep

- Access control (admin, non-admin, unauthenticated)
- Self-edit restriction
- Admin toggle test
- User list display

### New tests

- **Roles badges**: user with parent profile shows "Parent" badge; provider profile shows "Provider"; `is_admin` shows "Admin"; dual-role shows both; no profile shows "User"
- **Subscription badges**: parent with explorer tier shows "Explorer"; active shows "Active"; provider with starter shows "Starter"; professional shows "Professional"; business_plus shows "Business+"; no profiles shows em-dash
- Tests use `AccountsFixtures` for users, `KlassHero.Factory` with `:parent_profile_schema` for parent profiles, and `KlassHero.Factory.insert(:provider_profile_schema, ...)` for provider profiles

## Files Changed

| File | Action |
| --- | --- |
| `lib/klass_hero/accounts/.../schemas/user.ex` | Add aliases + `has_one :parent_profile` and `has_one :provider_profile` |
| `lib/klass_hero_web/live/admin/user_live.ex` | Rename → `account_live.ex`, rewrite fields, add `item_query` |
| `lib/klass_hero_web/router.ex` | Route and module name update |
| `lib/klass_hero_web/components/layouts/admin.html.heex` | Sidebar link + label |
| `lib/klass_hero_web/components/layouts/app.html.heex` | Two admin entry-point links |
| `test/.../admin/user_live_test.exs` | Rename → `account_live_test.exs`, update + add tests |

## Not Changed

- ParentProfileSchema, ProviderProfileSchema — untouched
- ProviderLive (admin) — stays as-is for detailed provider management
- Domain models, ports, use cases — untouched
- No migrations
