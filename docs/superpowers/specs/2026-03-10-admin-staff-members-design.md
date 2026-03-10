# Admin Staff Members Dashboard — Design Spec

**Issue:** #339 (parent: #337)
**Date:** 2026-03-10

## Goal

Add Staff Members management to the admin dashboard following established Backpex LiveResource patterns. Admin can view all staff members across providers and toggle their active status.

## Decisions

| Concern          | Decision                                       | Rationale                                                    |
| ---------------- | ---------------------------------------------- | ------------------------------------------------------------ |
| Editable fields  | `active` only                                  | Admin is a safety valve, not the owner                       |
| Create/Delete    | Disabled                                       | Staff members are provider-owned resources                   |
| Provider display | `belongs_to` association + `BelongsTo` field   | Show business name instead of raw UUID                       |
| Filtering        | ActiveFilter (Boolean) + searchable fields     | Matches existing admin patterns; no hardcoded role lists     |
| Domain events    | None                                           | No downstream projections consume staff active status        |

## Changes

### New Files

#### `lib/klass_hero_web/live/admin/staff_live.ex`

Backpex LiveResource. Follows UserLive/ProviderLive pattern.

- `can?/3`: allow `:index`, `:show`, `:edit`. Deny `:new`, `:delete`, and catch-all.
- No `on_item_updated/2` — no cross-context event consumers.
- Fields:

| Field          | Type                 | Index | Show | Edit         | Searchable       | Orderable |
| -------------- | -------------------- | ----- | ---- | ------------ | ---------------- | --------- |
| first_name     | Text                 | yes   | yes  | readonly     | yes              | yes       |
| last_name      | Text                 | yes   | yes  | readonly     | yes              | yes       |
| provider       | BelongsTo            | yes   | yes  | readonly     | yes              | no        |
| role           | Text                 | yes   | yes  | readonly     | yes              | yes       |
| email          | Text                 | yes   | yes  | readonly     | yes              | no        |
| active         | Boolean              | yes   | yes  | **editable** | no               | yes       |
| bio            | Textarea             | no    | yes  | readonly     | no               | no        |
| tags           | Text (custom render) | no    | yes  | readonly     | no               | no        |
| qualifications | Text (custom render) | no    | yes  | readonly     | no               | no        |
| inserted_at    | DateTime             | yes   | yes  | readonly     | no               | yes       |

BelongsTo field configuration requires `display_field: :business_name` to render the provider's name in the index/show views.

Array fields (`tags`, `qualifications`) use a custom render joining values with commas, matching the `categories` field pattern in ProviderLive:

```elixir
render: fn assigns ->
  ~H"""
  <p>{Enum.join(@value || [], ", ")}</p>
  """
end
```

#### `lib/klass_hero_web/live/admin/filters/active_filter.ex`

Boolean filter for active status. Same pattern as `VerifiedFilter`. Label: "Active Status".

Options: "Active" (`x.active == true`), "Inactive" (`x.active == false`).

### Modified Files

#### `lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex`

1. Replace `field :provider_id, :binary_id` with `belongs_to :provider, ProviderProfileSchema, type: :binary_id`.
2. Add `admin_changeset/3` — Backpex requires 3-arg signature (`schema, attrs, metadata`). The `metadata` keyword list contains `:assigns` with the current admin scope, but this changeset ignores it since only `:active` is cast (no audit trail fields needed, unlike ProviderProfileSchema which uses metadata for `verified_by_id`).
3. Existing changesets remain unchanged — they reference `:provider_id` which `belongs_to` still defines implicitly.

**Safety of `belongs_to` change:**

- No migration needed — the `provider_id` DB column is unchanged.
- StaffMemberMapper accesses `schema.provider_id` directly (not through the association) — continues working.
- StaffMemberRepository queries and inserts use `:provider_id` — continues working.
- Test fixtures pass `provider_id` via attrs — continues working.

#### `lib/klass_hero_web/router.ex`

Add inside the `:backpex_admin` live_session:

```elixir
live_resources("/staff", StaffLive, only: [:index, :show, :edit])
```

#### `lib/klass_hero_web/components/layouts/admin.html.heex`

Add sidebar nav item for "Staff Members" with `hero-user-group` icon, navigating to `/admin/staff`.

## Out of Scope

- Staff member creation/deletion from admin
- Headshot upload management
- Domain event publishing for active status changes
- Tags/qualifications editing from admin
