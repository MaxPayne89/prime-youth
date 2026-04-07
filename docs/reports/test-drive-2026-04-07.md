# Test Drive Report - 2026-04-07

## Scope
- Mode: unstaged
- Branch: working tree (uncommitted) vs HEAD
- Files changed: 18
- Issue: #553 — Stripe Identity integration for provider verification
- Routes affected:
  - `POST /webhooks/stripe` (Stripe Identity webhook)
  - `GET /provider/stripe-identity/return` (post-verification redirect)

---

## Backend Checks

### Passed

| Check | Description | Result |
|-------|-------------|--------|
| A1 | Migration applied — `stripe_identity_session_id` and `stripe_identity_status` columns present on `providers` table | PASS |
| A2 | Schema fields — `ProviderProfileSchema` declares both `:stripe_identity_session_id` and `:stripe_identity_status` with correct defaults | PASS |
| A3 | Domain model `stripe_identity_initiated/2` — sets `stripe_identity_status: :pending` and `stripe_identity_session_id` | PASS |
| A4 | Domain model `record_stripe_identity_result/3` + `stripe_identity_verified?/1` — persists result; predicate returns `true` only for `:verified` | PASS |
| A5 | Age gate logic in `ProcessStripeIdentityWebhook` — under-18 DOB yields `:requires_input`; invalid DOB passes through with warning log | PASS |
| A6 | Webhook route — `POST /webhooks/stripe` present in router | PASS |
| A7 | Return URL route — `GET /provider/stripe-identity/return` present in router | PASS |
| A8 | Regression tests — `auto_verify_integration_test.exs` and `check_provider_verification_status_test.exs` updated and passing (8/8) | PASS |

### Issues Found

- **warning**: `ProcessStripeIdentityWebhook` calls `Phoenix.PubSub.broadcast/3` directly from the application layer, introducing a Phoenix infrastructure dependency.
  - Location: `lib/klass_hero/provider/application/use_cases/verification/process_stripe_identity_webhook.ex:101`
  - Expected: PubSub broadcasting decoupled via a port (e.g. `ForBroadcastingProviderUpdates`)
  - Actual: `Phoenix.PubSub.broadcast` called directly — pragmatic but crosses layer boundary
  - Severity: warning (accepted trade-off; no port abstraction for PubSub exists elsewhere in the codebase)

- **warning**: `cast_stripe_status/1` in the mapper handles `:processing` and `:created` Stripe statuses by mapping them to `:pending`. These statuses are not part of the domain model's declared status set.
  - Location: `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex`
  - Expected: only statuses in the domain model's `@valid_statuses` list should appear
  - Actual: extra statuses handled silently — consider removing or documenting if not reachable
  - Severity: warning

---

## UI Checks (Playwright MCP)

Chrome extension was unavailable during this test-drive run. UI checks could not be executed automatically.

### Pages Tested

| Check | Description | Result |
|-------|-------------|--------|
| B1 | Identity Verification panel visible on `/provider/dashboard/edit` | MANUAL — pending |
| B2 | Status badge shows "Not started" for new provider | MANUAL — pending |
| B3 | "Verify Identity" button present when status is `:not_started` | MANUAL — pending |
| B4 | `GET /provider/stripe-identity/return` redirects to `/provider/dashboard` with flash | MANUAL — pending |
| B5 | Responsive layout at 375×667 (mobile) — panel stacks correctly | MANUAL — pending |

### Issues Found
- None (pending manual verification)

---

## Edge Cases

| Check | Description | Result |
|-------|-------------|--------|
| C1 | Under-18 DOB from Stripe verified_outputs → `:requires_input` (not `:verified`) | PASS (code review) |
| C2 | Nil DOB (Stripe didn't return it) → age gate passes, `:verified` stored | PASS (code review) |
| C3 | Invalid DOB format from Stripe → warning logged, age gate passes | PASS (code review) |
| C4 | Webhook received for unknown session ID → `{:error, :not_found}` logged, 200 returned to Stripe | PASS (code review) |
| C5 | Duplicate webhook delivery (Stripe retries) → idempotent; `update` overwrites with same status | PASS (code review) |
| C6 | Provider clicks "Verify Identity" when already verified → `{:error, :already_verified}` flash, no Stripe call | PASS (code review) |

---

## Auto-Fixes Applied

- `lib/klass_hero_web/plugs/verify_stripe_webhook_signature.ex`: Fixed `@moduledoc` string interpolation compile error — escaped `#{timestamp}` → `\#{timestamp}` in heredoc docstring
- `lib/klass_hero_web/router.ex`: Fixed double module prefix bug — `scope "/provider", KlassHeroWeb do` inside outer `KlassHeroWeb` scope produced `KlassHeroWeb.KlassHeroWeb.StripeIdentityReturnController`; changed to bare `scope "/provider" do`
- `lib/klass_hero_web/live/provider/dashboard_live.ex`: Removed duplicate `handle_event("start_stripe_identity")` clause; regrouped with other upload event handlers
- `lib/klass_hero/provider/application/use_cases/verification/process_stripe_identity_webhook.ex`: Replaced `Date.new!` + rescue with idiomatic `case Date.new/3`; removed redundant inline comments
- `lib/klass_hero_web/controllers/stripe_webhook_controller.ex`: Merged duplicate `requires_input` / `canceled` webhook handler clauses into one with `when type in [...]`

---

## Issues Filed
- None

---

## Recommendations

1. **Manual UI verification required** — Chrome extension was unavailable. Before merge, manually verify:
   - Identity Verification panel renders on `/provider/dashboard/edit`
   - Return URL redirect and flash message work
   - Mobile responsive layout (375×667)
   - "Verify Identity" button requires a dev Stripe key; mark as manual-only until dev keys are configured

2. **Configure dev Stripe Identity key** — `STRIPE_IDENTITY_SECRET_KEY` and `STRIPE_IDENTITY_WEBHOOK_SECRET` are documented in `.env.example` but the full button-click flow cannot be tested without real Stripe test-mode keys. Add to onboarding docs / team secret store.

3. **Consider removing `:processing`/`:created` mapper branches** — if these Stripe-side statuses can never reach the webhook handler (since webhooks only fire for `verified`, `requires_input`, `canceled`), the extra `cast_stripe_status/1` clauses are dead code.
