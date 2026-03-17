# Feature: Configuration Registries

> **Context:** Shared | **Status:** Active
> **Last verified:** 17f796f3

## Purpose

Provides compile-time constant registries for subscription tiers, activity categories, and structured error IDs so that all bounded contexts reference a single source of truth without creating cyclic dependencies.

## What It Does

- **SubscriptionTiers** -- enumerates parent tiers (`:explorer`, `:active`) and provider tiers (`:starter`, `:professional`, `:business_plus`), exposes validation predicates, default-tier accessors, and a safe binary-to-atom cast for provider tiers
- **Categories** -- enumerates a closed set of activity category strings (`sports`, `arts`, `music`, `education`, `life-skills`, `camps`, `workshops`) with a validity check
- **ErrorIds** -- defines dotted-notation string constants (e.g. `program.catalog.detail.not_found`) for structured log correlation across Program Catalog, Participation, and Identity contexts

## What It Does NOT Do

| Out of Scope | Handled By |
|---|---|
| Runtime configuration or admin CRUD of tiers/categories | Not implemented -- values are compile-time constants |
| Tier-based authorization and limit enforcement | Entitlements context |
| Displaying error IDs in user-facing flash messages | Web layer (flash messages use Gettext translations) |
| Mapping tiers to pricing or payment logic | Enrollment context |

## Business Rules

```
GIVEN a parent account is created
WHEN  no tier is explicitly assigned
THEN  the default parent tier is :explorer
```

```
GIVEN a provider account is created
WHEN  no tier is explicitly assigned
THEN  the default provider tier is :starter
```

```
GIVEN any module needs to validate a category value
WHEN  the value is not in the canonical list of 7 categories
THEN  valid_category?/1 returns false
```

```
GIVEN untrusted binary input for a provider tier
WHEN  cast_provider_tier/1 is called
THEN  it returns {:ok, atom} for known tiers or {:error, :invalid_tier} otherwise
      (never calls String.to_existing_atom, avoiding crash on bad input)
```

```
GIVEN a domain-level error occurs (e.g. stale entry, duplicate record)
WHEN  the error is logged
THEN  the corresponding ErrorIds function supplies a stable dotted-notation string
      for log correlation and support debugging
```

## How It Works

These modules are pure functions over compile-time module attributes -- no GenServer, no database, no runtime state. Every public function returns a literal or performs a `Map.fetch/2` against a compile-time map.

```
SubscriptionTiers
  @parent_tiers   [:explorer, :active]
  @provider_tiers [:starter, :professional, :business_plus]
  @provider_tier_strings  %{"starter" => :starter, ...}  (built at compile time)

Categories
  @categories ["sports", "arts", "music", "education", "life-skills", "camps", "workshops"]

ErrorIds
  Zero-arity functions returning dotted strings, grouped by context:
    program.*         -- Program Catalog
    participation.*   -- Participation (sessions + records)
    identity.*        -- Identity (parent, provider, child)
```

## Dependencies

| Direction | Context | What |
|---|---|---|
| Provides to | Identity | Tier validation, category validation, error IDs for parent/provider/child |
| Provides to | Entitlements | Tier names and defaults for limit lookups |
| Provides to | Program Catalog | Category list for filtering, error IDs for program operations |
| Provides to | Participation | Error IDs for session and participation record operations |
| Provides to | Enrollment | Tier names for subscription-gated booking logic |
| Requires | (none) | No external dependencies -- pure compile-time constants |

## Edge Cases

- **Non-atom input to tier validators** -- `valid_parent_tier?/1` and `valid_provider_tier?/1` guard on `is_atom/1`; any non-atom input returns `false` without raising
- **Non-binary input to `cast_provider_tier/1`** -- a catch-all clause returns `{:error, :invalid_tier}` for non-binary values
- **Unknown category string** -- `valid_category?/1` returns `false`; no "all" pseudo-category exists in the registry (filtering for "all categories" is handled by callers omitting the filter)
- **ErrorIds with changeset argument** -- `session_create_failed/1`, `session_update_failed/1`, `participation_record_create_failed/1`, and `participation_record_update_failed/1` accept an `%Ecto.Changeset{}` argument for pattern-match clarity but do not inspect it; they return the same constant string regardless of changeset contents

## Roles & Permissions

| Role | Relevance |
|---|---|
| (all) | Infrastructure module -- no direct user interaction. Consumed by domain services, use cases, and adapters across all contexts. |

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
