# Dual-Role Staff + Provider Design

**Issue:** #565 — Allow one user account to hold both staff member and provider roles
**Date:** 2026-04-05
**Status:** Draft

## Context

Staff members can activate via an invitation link and create a user account (issue #363). Currently, activation locks the user to `intended_roles: [:staff_provider]`. This design adds an opt-in path for activated staff members to also become independent providers, holding both roles simultaneously.

## Goal

Allow a staff member who activates via invite to optionally also become an independent provider — with both roles recognized, both dashboards accessible, and clear navigation between them.

## Design Decisions

### Opt-in at registration (not automatic)

During the staff invite registration form, a checkbox ("I also want to offer my own programs") controls whether a provider profile is created. Staff members who just want to be instructors are unaffected.

**Rationale:** Not every staff member wants to run their own business. Automatic provider profile creation adds noise. Opt-in respects user intent.

### Two dashboards with cross-navigation (not merged)

Dual-role users access both `/provider/dashboard` (manage their business) and `/staff/dashboard` (view personal assignments). A contextual link on each dashboard navigates to the other.

**Rationale:** The provider dashboard manages a business entity. The staff dashboard shows personal assignments. These are conceptually distinct responsibilities — merging them conflates "managing my business" with "seeing what's assigned to me" and would further bloat the 1,900+ line provider dashboard.

### Provider dashboard as default landing

When a dual-role user logs in, they land on `/provider/dashboard`. The precedence in `redirect_provider_or_staff_from_parent_routes` is swapped so provider takes priority over staff.

**Rationale:** The user explicitly opted into being a provider. Staff-only users (who didn't opt in) still land at `/staff/dashboard`.

## Changes

### 1. Staff Registration Flow

**File:** `lib/klass_hero_web/live/user_live/staff_invitation.ex`

- Add a checkbox to the registration form: "I also want to offer my own programs"
- When checked, set `intended_roles: [:staff_provider, :provider]`
- Include `create_provider_profile: true` in the `:staff_user_registered` event payload

**File:** `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`

- `staff_registration_changeset/3` must accept `[:staff_provider, :provider]` as valid intended_roles (currently locks to `[:staff_provider]`)

### 2. Provider Profile Creation via Event Handler

**File:** `lib/klass_hero/accounts/adapters/driving/events/staff_invitation_handler.ex`

- On `:staff_user_registered` event, check for `create_provider_profile: true` in payload
- If present, create a starter provider profile with:
  - `identity_id` set to the new user's ID
  - `originated_from: :staff_invite`
  - `subscription_tier: :starter`
  - `business_name` set to the user's full name as a placeholder (editable later via provider profile form)

### 3. Migration: `originated_from` on Provider Profiles

**New migration file**

```elixir
alter table(:provider_profiles) do
  add :originated_from, :string, default: "direct", null: false
end
```

Values:
- `"direct"` — registered normally (default, backfills all existing records)
- `"staff_invite"` — created through staff activation flow

### 4. Provider Profile Domain Model & Schema

**File:** `lib/klass_hero/provider/domain/models/provider_profile.ex`

- Add `originated_from` field (atom: `:direct` or `:staff_invite`)

**File:** `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex`

- Add `originated_from` string field
- Include in relevant changesets

**File:** `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex`

- Map `originated_from` between string (schema) and atom (domain)

### 5. Router Precedence Swap

**File:** `lib/klass_hero_web/user_auth.ex`

In `redirect_provider_or_staff_from_parent_routes/3`, swap the cond order:

```elixir
cond do
  Scope.provider?(scope) -> redirect to /provider/dashboard
  Scope.staff_provider?(scope) -> redirect to /staff/dashboard
  true -> pass through
end
```

Same precedence change in `signed_in_path/1` and `dashboard_path/1`.

### 6. Cross-Navigation UI

**File:** `lib/klass_hero_web/live/provider/dashboard_live.ex`

- When `@current_scope` has both `:provider` and `:staff_provider` roles, show a link: "View your assignments" → `/staff/dashboard`

**File:** `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`

- When `@current_scope` has both roles, show a link: "Manage your business" → `/provider/dashboard`

### 7. Scope & Role Resolution

**No changes needed.** `Scope.resolve_roles/1` already independently queries for provider profile and staff member. A user with both will have both `scope.provider` and `scope.staff_member` populated, and both `:provider` and `:staff_provider` in `scope.roles`.

## What's NOT in Scope

- No dashboard merging — each dashboard stays as-is
- No new dashboard pages
- No role switching UI beyond cross-nav links
- No changes to existing staff-only or provider-only user flows
- No changes to parent role handling

## Test Plan

- **Registration:** Staff invite with checkbox checked → user gets `[:staff_provider, :provider]` roles, provider profile created with `originated_from: :staff_invite`
- **Registration (opt-out):** Staff invite without checkbox → user gets `[:staff_provider]` only, no provider profile, current behavior unchanged
- **Scope resolution:** Dual-role user's scope has both `provider` and `staff_member` populated
- **Routing:** Dual-role user redirected to `/provider/dashboard` (not staff), can access both `/provider/*` and `/staff/*` routes
- **Cross-nav:** Link appears on both dashboards only when user has both roles
- **Migration:** Existing provider profiles get `originated_from: "direct"` default

## Dependencies

- Issue #363 (staff activation flow) — already implemented
- Issue #364 (profile creation after activation) — related, may overlap
- Issue #260 (starter/pro profile form) — the provider profile form dual-role users will see
