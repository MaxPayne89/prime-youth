# Starter Tier — 2 Program Limit (Excludes Business-Assigned Programs)

**Issue:** #360
**Date:** 2026-04-11
**Status:** Approved

## Summary

Enforce the starter provider tier's 2-program limit. Programs are tracked with an explicit `origin` field (`self_posted` / `business_assigned`). Only self-posted programs count toward the limit. Business-assigned programs are excluded, but no UI to create them exists yet — the field defaults to `self_posted` and is ready for the future assignment flow.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Origin tracking | Explicit `origin` column on `programs` table | Simplicity and explicitness over inferring from staff assignments |
| Default origin | `self_posted` for all programs | Only creation path today; `business_assigned` set when assignment flow is built |
| Enforcement | Server-side guard in `CreateProgram` use case + UI disable on dashboard | Defense-in-depth: use case is authoritative, UI prevents wasted effort |
| Cross-context data | LiveView passes tier holder into use case | Avoids building an ACL adapter for a single atom; LiveView already has provider profile |
| Counter display | Self-posted count against limit, no annotation | Business-assigned programs can't exist yet; revisit display when they can |
| Existing providers | No impact — `provider_tier_bypass` flag is active | Graceful over-limit behavior (disable button, block creation) for when flag is removed |

## Data Model

### Migration: Add `origin` to `programs`

```sql
ALTER TABLE programs
  ADD COLUMN origin VARCHAR(255) NOT NULL DEFAULT 'self_posted';

CREATE INDEX programs_provider_id_origin_index
  ON programs (provider_id, origin);
```

- Column: `origin`, type: `string`, not null, default: `"self_posted"`
- Composite index on `(provider_id, origin)` for efficient counting
- All existing programs are backfilled to `"self_posted"` via the default

### Domain Model: `Program`

Add `origin` field to the `Program` struct. Valid values: `:self_posted`, `:business_assigned`.

`Program.create/1` hardcodes `origin: :self_posted` — the only creation path today.

### Schema & Mapper

- `ProgramSchema` gains the `origin` string field
- Mapper converts between string (`"self_posted"`) and atom (`:self_posted`)

## Enforcement Logic

### Server-Side: `CreateProgram` Use Case

New flow:

1. Receive `attrs` and `tier_holder` (provider struct/map with `subscription_tier`)
2. Count self-posted programs: `program_repo.count_by_provider_and_origin(provider_id, :self_posted)`
3. Check entitlement: `Entitlements.can_create_program?(tier_holder, count)`
4. If `false` → return `{:error, :program_limit_reached}`
5. If `true` → create program with `origin: :self_posted`, persist, publish event

The `can_create_program?/2` function already respects the `:provider_tier_bypass` feature flag — always returns `true` when active.

### New Port & Adapter

- `ForListingPrograms` port: add `count_by_provider_and_origin(provider_id, origin)` callback returning `non_neg_integer()`
- Ecto repository adapter implements this listing callback with `SELECT COUNT(*) FROM programs WHERE provider_id = $1 AND origin = $2`

### Client-Side: Provider Dashboard

- At mount: compute `program_slots_used` from actual self-posted count (not hardcoded 0)
- When `program_slots_used >= program_slots_total`: disable "New Program" button with message "Upgrade your plan to add more programs"
- On successful creation: increment `program_slots_used`
- On `{:error, :program_limit_reached}`: show error flash (defense-in-depth path)

### Public API: `ProgramCatalog`

Update `create_program/1` to `create_program/2` — second argument is the `tier_holder` (provider domain model struct). The LiveView passes the provider profile it already has at mount. The public API delegates to the use case with both arguments.

## Over-Limit Behavior

When the tier bypass flag is eventually removed and a provider has more programs than their tier allows:

- Existing programs remain untouched
- "New Program" button is disabled
- Counter shows actual count against limit (e.g., "3 / 2 programs")
- Provider can delete programs or upgrade tier to regain creation ability

## Testing

### Unit Tests
- `Program.create/1` — origin defaults to `:self_posted`
- `Entitlements.can_create_program?/2` — starter at 0, 1, 2, 3 programs

### Use Case Tests
- `CreateProgram` with tier under limit → succeeds, program has `origin: :self_posted`
- `CreateProgram` with tier at limit → returns `{:error, :program_limit_reached}`
- `CreateProgram` with tier bypass active → always succeeds

### Repository Tests
- `count_by_provider_and_origin/2` — correct count, filters by origin, ignores other providers

### LiveView Tests
- Dashboard mounts with correct `program_slots_used`
- "New Program" button disabled at limit
- Creating a program increments counter
- Error flash on rejected creation

## Files Touched

1. **New migration** — add `origin` column + index to `programs`
2. **`Program` domain model** — add `origin` field
3. **`ProgramSchema`** — add `origin` field
4. **Program mapper** — string ↔ atom conversion for `origin`
5. **`ForStoringPrograms` port** — add `count_by_provider_and_origin/2` callback
6. **Program repository adapter** — implement count query
7. **`CreateProgram` use case** — add entitlement guard, accept `tier_holder`
8. **`ProgramCatalog` public API** — pass through `tier_holder` parameter
9. **Provider `DashboardLive`** — disable button at limit, init counter from real count
10. **Tests** — unit, use case, repository, LiveView

## Out of Scope

- Business-assigned program creation UI/flow
- Program list filtering by origin
- Counter annotation distinguishing self-posted from business-assigned
- ACL adapter for cross-context provider data (revisit if more cross-context needs arise)
