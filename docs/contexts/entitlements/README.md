# Context: Entitlements

> Pure domain service for subscription tier authorization. Contains no database, no persistence, and no OTP processes — it operates solely on domain entities via pure functions. Acts as a cross-context service consumed by Enrollment, Messaging, and the web layer to enforce tier-based limits and capabilities.

## What This Context Owns

- **Domain Concepts:** Parent tier limits (booking caps, cancellations, progress detail, messaging rights), provider tier limits (program caps, commission rates, media types, team seats, messaging rights), entitlement check logic, tier validation delegation
- **Data:** None — stateless, pure functions only. Tier limit tables are compile-time module attributes.
- **Processes:** None

## Key Features

All functionality lives in a single module (`KlassHero.Entitlements`). There are no separate feature docs.

| Feature | Status | Description |
|---|---|---|
| Booking cap checks | Active | `can_create_booking?/2`, `monthly_booking_cap/1` — enforces monthly booking limits per parent tier |
| Messaging initiation | Active | `can_initiate_messaging?/1` — scope-aware check supporting parent, provider, or dual-profile scopes |
| Program slot limits | Active | `can_create_program?/2`, `max_programs/1` — enforces program creation limits per provider tier |
| Commission rates | Active | `commission_rate/1` — returns tier-specific commission percentage for fee calculations |
| Free cancellations | Active | `free_cancellations_per_month/1` — returns monthly free cancellation allowance per parent tier |
| Progress detail level | Active | `progress_detail_level/1` — returns `:basic` or `:detailed` based on parent tier |
| Media type entitlements | Active | `media_entitlements/1` — returns allowed media types (avatar, gallery, video, promotional) per provider tier |
| Team seats | Active | `team_seats_allowed/1` — returns maximum team seats per provider tier |
| Tier info (UI) | Active | `parent_tier_info/1`, `provider_tier_info/1`, `all_parent_tiers/0`, `all_provider_tiers/0` — full tier details for comparison pages |
| Tier validation | Active | `valid_parent_tier?/1`, `valid_provider_tier?/1`, `parent_tiers/0`, `provider_tiers/0`, `default_parent_tier/0`, `default_provider_tier/0` — delegated to `Shared.SubscriptionTiers` |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Enrollment | `can_create_booking?/2` | Checks if a parent's monthly booking cap allows a new booking |
| Enrollment | `commission_rate/1` | Retrieves provider commission rate for fee calculation |
| Enrollment | `free_cancellations_per_month/1` | Determines if a cancellation is free or chargeable |
| Messaging | `can_initiate_messaging?/1` | Gates whether a user (parent or provider) can start a new conversation |
| Program Catalog | `can_create_program?/2` | Checks if a provider can list a new program |
| Web Layer | `parent_tier_info/1`, `provider_tier_info/1`, `all_*_tiers/0` | Drives tier comparison and upgrade pages |
| Family / Provider | `valid_parent_tier?/1`, `valid_provider_tier?/1` | Validates tier values during profile creation/update |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| — | — | None. This is a pure function module with no side effects or outbound calls. |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| Parent Tier | Subscription level for a parent account. Currently `explorer` (free/default) or `active` (paid). |
| Provider Tier | Subscription level for a provider account. Currently `starter` (default), `professional`, or `business_plus`. |
| Booking Cap | Maximum number of bookings a parent can create per calendar month. Explorer = 2, Active = unlimited. |
| Commission Rate | Percentage of each transaction retained by the platform. Decreases with higher provider tiers (18% / 12% / 8%). |
| Free Cancellations | Number of booking cancellations per month that incur no fee. Explorer = 0, Active = 1. |
| Progress Level | Granularity of child progress data visible to a parent. `:basic` or `:detailed`. |
| Media Types | Categories of media a provider may upload. Tiers progressively unlock: avatar, gallery, video, promotional. |
| Team Seats | Number of staff/team member accounts a provider may invite. Starter/Professional = 1, Business Plus = 3. |
| Tier Holder | Any map with a `:subscription_tier` key — the input contract for most entitlement functions. |
| Scope | A map with `:parent` and/or `:provider` keys, used by `can_initiate_messaging?/1` for dual-profile resolution. |

## Business Decisions

### Parent Tier Limits

| Tier | Booking Cap | Free Cancellations | Progress Detail | Can Initiate Messaging |
|---|---|---|---|---|
| `explorer` (default) | 2/month | 0 | Basic | No |
| `active` | Unlimited | 1/month | Detailed | Yes |

### Provider Tier Limits

| Tier | Max Programs | Commission | Media Types | Team Seats | Can Initiate Messaging |
|---|---|---|---|---|---|
| `starter` (default) | 2 | 18% | Avatar only | 1 | No |
| `professional` | 5 | 12% | Avatar, Gallery, Video | 1 | Yes |
| `business_plus` | Unlimited | 8% | All (incl. Promotional) | 3 | Yes |

### Key Rules

- When a limit is `:unlimited`, the check always passes regardless of current count.
- `nil` tiers fall back to the default tier for each role (`explorer` for parents, `starter` for providers).
- Messaging initiation requires at least one profile (parent or provider) with messaging rights. If a scope has both, either having the right is sufficient.
- Tier name atoms are the canonical identifiers. String-to-atom casting is handled by `Shared.SubscriptionTiers.cast_provider_tier/1` using a compile-time lookup map (never `String.to_atom/1`).

## Assumptions & Open Questions

- **Assumption:** Tier limits are static and change only via code deploys. There is no runtime configuration or per-account overrides.
- **Assumption:** The two-tier parent model (explorer/active) and three-tier provider model (starter/professional/business_plus) are sufficient for launch.
- **Open Question:** Will custom/enterprise tier limits be needed for large provider accounts?
- **Open Question:** Should tier upgrade/downgrade events be published so other contexts can react (e.g., revoking excess programs when downgrading)?
- **Open Question:** Will parent tiers expand beyond two levels (e.g., a "family" tier with multi-child discounts)?
- **Open Question:** How will annual vs. monthly billing interact with entitlement checks (if at all)?

## Source Files

| File | Purpose |
|---|---|
| `lib/klass_hero/entitlements.ex` | All entitlement logic — tier limit lookups, authorization checks, tier info |
| `lib/klass_hero/shared/subscription_tiers.ex` | Tier name vocabulary, validation, defaults, string casting (shared kernel) |

## Boundary Configuration

```elixir
use Boundary,
  top_level?: true,
  deps: [KlassHero.Shared],
  exports: []
```

The Entitlements context depends only on the Shared kernel. It exports nothing (callers reference the module directly as `KlassHero.Entitlements`).
