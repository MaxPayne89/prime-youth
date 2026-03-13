# Admin Consents Overview — Design Spec

**Issue:** #341
**Date:** 2026-03-13
**Status:** Approved

## Summary

Read-only Backpex LiveResource for viewing consent records in the admin dashboard. No grant/withdraw actions — purely an overview for compliance visibility.

## Schema Changes

Add `belongs_to` associations to `ConsentSchema`:

```elixir
belongs_to :child, ChildSchema
belongs_to :parent, ParentProfileSchema
```

Replaces existing `field :child_id, :binary_id` and `field :parent_id, :binary_id`. No migration needed.

Add a no-op `admin_changeset/3` to `ConsentSchema` (Backpex requires changeset references in adapter config even when create/edit are denied):

```elixir
def admin_changeset(schema, _attrs, _metadata), do: change(schema)
```

## ConsentLive (Backpex LiveResource)

**File:** `lib/klass_hero_web/live/admin/consent_live.ex`

**Actions:** `:index`, `:show` only. `can?/3` denies `:new`, `:edit`, `:delete`.

**Adapter config:** Uses `ConsentSchema.admin_changeset/3` for both `create_changeset` and `update_changeset`.

### Fields

| Field | Type | Index | Show | Searchable | Orderable | Notes |
|-------|------|-------|------|------------|-----------|-------|
| child | BelongsTo | yes | yes | yes | no | `display_field: :first_name`; full name via custom render |
| parent | BelongsTo | yes | yes | yes | no | `display_field: :display_name` |
| consent_type | Text | yes | yes | yes | yes | Custom render: humanized label |
| status | Text | yes | yes | no | no | Custom render as badge (not a DB field — driven by `withdrawn_at`) |
| granted_at | DateTime | yes | yes | no | yes | |
| withdrawn_at | DateTime | no | yes | no | no | |

**Default sort:** `inserted_at` desc (Ecto timestamp, not a displayed field).

**Search:** Child first_name (via BelongsTo display_field), parent display_name, consent_type. Full child name search (first + last) may require `item_query/3` override if BelongsTo only searches the display_field.

### Preloading via `item_query/3`

Override `item_query/3` to preload `:child` and `:parent` associations:

```elixir
def item_query(query, _live_action, _assigns) do
  from c in query, preload: [:child, :parent]
end
```

### Compliance Banner

Override `render_resource_slot/3` at the `:before_main` position on the `:index` action:

> "Consent records are append-only for compliance. Withdrawals are recorded with timestamps — records are never deleted."

### Status Badge Rendering

Via custom `render` function on the `status` Text field:
- `withdrawn_at` is nil → green badge "Active"
- `withdrawn_at` is set → amber badge "Withdrawn"

## Filters

### ConsentTypeFilter

**File:** `lib/klass_hero_web/live/admin/filters/consent_type_filter.ex`

Uses `Backpex.Filters.Select` with the 5 consent types as options:
- Provider Data Sharing
- Photo Marketing
- Photo Social Media
- Medical
- Participation

### ConsentStatusFilter

**File:** `lib/klass_hero_web/live/admin/filters/consent_status_filter.ex`

Uses `Backpex.Filters.Select` with custom `query/4` override for NULL-based logic:
- All (no filter applied)
- Active: `WHERE withdrawn_at IS NULL`
- Withdrawn: `WHERE withdrawn_at IS NOT NULL`

Cannot use standard `Backpex.Filters.Boolean` here since this isn't a simple boolean field — it's derived from a nullable timestamp.

## Router

Add inside existing Backpex admin `live_session` scope:

```elixir
live_resources("/consents", ConsentLive, only: [:index, :show])
```

## Tests

**File:** `test/klass_hero_web/live/admin/consent_live_test.exs`

Test data: use existing `consent_schema_factory` from `test/support/factory.ex`. May need updating after schema changes from `field` to `belongs_to` (factory currently sets raw IDs).

- Index renders consent list with child name, parent name, consent type, status badge
- Search by child name returns matching results
- Search by parent display name returns matching results
- Consent type filter narrows results
- Status filter (active/withdrawn) narrows results
- Show page displays full consent details including granted_at and withdrawn_at
- No create/edit/delete actions accessible (read-only enforcement)
