# Provider Profiles Admin Dashboard — Design

**Issue:** #338
**Date:** 2026-03-09

## Decision

Backpex LiveResource at `lib/klass_hero_web/live/admin/provider_live.ex`. Same pattern as UserLive — operates directly on `ProviderProfileSchema`, bypassing Ports & Adapters (pragmatic exception scoped to admin read + limited edit).

## Route

```elixir
# Inside existing :backpex_admin live_session
live_resources("/providers", ProviderLive, only: [:index, :show, :edit])
```

## Changeset

New `admin_changeset/3` on `ProviderProfileSchema`. Only casts `verified` and `subscription_tier`. Prevents accidental changes to provider-owned fields.

## Access Control

| Action | Allowed |
|--------|---------|
| :new | false (providers self-register) |
| :delete | false (GDPR process) |
| :index | true |
| :show | true |
| :edit | true |

## Field Visibility

| Field | Index | Show | Edit |
|---|---|---|---|
| business_name | searchable, sortable | yes | readonly |
| description | no | yes | no |
| phone | no | yes | no |
| website | no | yes | no |
| address | no | yes | no |
| verified | yes, sortable | yes | yes (toggle) |
| subscription_tier | yes, sortable | yes | yes (select) |
| categories | no | yes | no |
| inserted_at | yes, sortable | yes | no |

## Audit Logging

Not needed. Existing domain events (verify/unverify) track admin_id. Future event-sourcing covers the rest.

## Testing

- Admin can access index, show, edit
- Non-admin users blocked
- Only verified + subscription_tier editable
- Search by business_name works
