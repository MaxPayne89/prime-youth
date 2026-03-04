# Subscription Upgrade Path Design

**Issue:** #262 — Provider Registration Defaults to Starter — No Upgrade Path
**Date:** 2026-03-04

## Problem

Providers auto-assigned `:starter` tier at registration with no way to change it.
Need both a post-registration upgrade path and tier selection during registration.

## Decisions

- **Free instant switch** — no payment integration (MVP)
- **Bidirectional** — upgrade and downgrade both allowed
- **Dedicated subscription page** at `/provider/subscription`
- **Registration tier selector** — conditional UI when provider role checked

## 1. Domain Layer

No migration needed. `subscription_tier` column already exists on `provider_profiles`.

### New: `ProviderProfile.change_tier/2`

Pure function on the domain model. Accepts current profile + new tier atom.
Returns `{:ok, updated_profile}` or `{:error, reason}`.

Validations:
- New tier must be valid provider tier (via `SubscriptionTiers`)
- New tier must differ from current tier

### New: `ChangeSubscriptionTier` use case

`Provider.Application.UseCases.Providers.ChangeSubscriptionTier`

Orchestrates: domain validation → repository update.
Accepts provider profile + new tier atom.

### New: `Provider.change_subscription_tier/2`

Context facade function. Delegates to use case.

## 2. Subscription Page (`/provider/subscription`)

### Route

`/provider/subscription` in `:require_provider` live_session.

### LiveView: `KlassHeroWeb.Provider.SubscriptionLive`

**Mount:**
- Read provider profile from `@current_scope.provider`
- Load all provider tiers via `Entitlements.all_provider_tiers()`

**UI (mobile-first):**
- Header: "Manage Your Plan"
- 3 stacked cards (mobile) / 3-column grid (desktop)
- Each card uses `pricing_card` component showing:
  - Tier name + label
  - Max programs, commission rate, media types, team seats, messaging
- Current tier: "Current Plan" badge, disabled button
- Other tiers: "Switch to [Plan]" button

**Event:** `"switch_tier"` with tier value → calls `Provider.change_subscription_tier/2`
→ flash "Switched to [Plan] Plan" → re-render

## 3. Registration Tier Selection

### UI Change in `UserLive.Registration`

When provider checkbox checked → show 3 compact radio cards below:
- Starter: "2 programs, 18% commission"
- Professional: "5 programs, 12% commission"
- Business Plus: "Unlimited programs, 8% commission"

Starter pre-selected. Hidden form field: `user[provider_subscription_tier]`.

### Data Flow

1. `User` schema: add `:provider_subscription_tier` virtual field
2. `Accounts.register_user/1`: pass tier through to domain event payload
3. Integration event `user_registered` payload: include `provider_subscription_tier`
4. Provider profile creation handler: read tier from event, default to `:starter`

This crosses Accounts → Provider boundary via the existing event system.

## 4. Dashboard CTA

On provider dashboard Overview tab, below business profile card:
- Banner showing current plan name
- "Manage Plan" link to `/provider/subscription`
- If Starter tier: "Upgrade your plan to unlock more features"

## 5. Testing

| Layer | Test | What |
|-------|------|------|
| Domain | `ProviderProfile.change_tier/2` | Valid tier, same tier rejection, invalid tier |
| Use case | `ChangeSubscriptionTier` | Happy path, error cases |
| LiveView | `SubscriptionLive` | Mount shows 3 plans, current highlighted, switch works |
| LiveView | `Registration` | Provider checkbox shows/hides tier selector, tier persists |
| Integration | Full flow | Register with tier → provider profile has correct tier |

## Files Affected

**New files:**
- `lib/klass_hero/provider/application/use_cases/providers/change_subscription_tier.ex`
- `lib/klass_hero_web/live/provider/subscription_live.ex`
- `test/klass_hero/provider/.../change_subscription_tier_test.exs`
- `test/klass_hero_web/live/provider/subscription_live_test.exs`

**Modified files:**
- `lib/klass_hero/provider/domain/models/provider_profile.ex` — add `change_tier/2`
- `lib/klass_hero/provider.ex` — add `change_subscription_tier/2` facade
- `lib/klass_hero_web/router.ex` — add `/provider/subscription` route
- `lib/klass_hero_web/live/provider/dashboard_live.ex` — add CTA banner
- `lib/klass_hero_web/live/user_live/registration.ex` — add tier selector
- `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex` — virtual field
- `lib/klass_hero/accounts.ex` — pass tier through registration
- Integration event handler — read tier from payload
