# Test Drive Report - 2026-04-03

## Scope
- Mode: unstaged (issue #586 changes not yet committed)
- Branch: `feature/565-dual-role-staff-provider`
- Files changed: 6 (program_components.ex, dashboard_live.ex, create_direct_conversation.ex, messaging.ex, program_presenter.ex, family_programs_test.exs)
- Routes affected: none (uses existing `/messages/:id`)

## Backend Checks

> Note: Tidewave MCP unavailable (not configured for this project). Playwright MCP unavailable.
> Backend verification performed via `mix run --no-start` and targeted test suite.

### Passed

| Check | Description | Result |
|-------|-------------|--------|
| A1 | `Messaging.create_direct_conversation/2` exported alongside existing `/3` and `/4` | PASS |
| A2 | `CreateDirectConversation.execute/2` compiled and exported | PASS |
| A3 | `@user_resolver` config wires to `KlassHero.Messaging.Adapters.Driven.Accounts.UserResolver` | PASS |
| A4 | `UserResolver.get_user_id_for_provider/1` implemented | PASS |
| A5 | `ProgramPresenter.to_card_view/1` returns `provider_id` field | PASS — `%{id: "test-id", provider_id: "provider-uuid", title: "Test"}` |
| A6 | `DashboardLive.handle_event/3` compiled | PASS |
| A7 | 398 dashboard + messaging tests pass, 0 failures | PASS |
| A8 | Full suite 3795 tests, 0 failures after all changes | PASS |
| A9 | `mix compile --warnings-as-errors` clean (no warnings in klass_hero app) | PASS |

### Issues Found
None

## UI Checks (Playwright MCP)

> Playwright MCP not available in this session. Manual verification recommended.

### Pages Tested

| Check | Description | Result |
|-------|-------------|--------|
| B1 | `/dashboard` — Contact Provider button renders on active cards | SKIPPED (no Playwright) |
| B2 | Clicking Contact Provider → navigates to `/messages/:id` | SKIPPED |
| B3 | Expired program cards — no Contact Provider button | SKIPPED |
| B4 | Free-tier parent → flash error "Upgrade your plan" | SKIPPED |
| B5 | Double-click (idempotency) → same conversation URL | SKIPPED |
| B6 | Mobile (375px) — button layout | SKIPPED |

## Edge Cases

| Check | Description | Result |
|-------|-------------|--------|
| C1 | Programs with `provider_id: nil` — button does not render | PASS — `if(!item.expired, do: card.provider_id)` returns nil; component `:if` guard hides button |
| C2 | Fabricated `contact_provider` phx event with unknown provider_id — silently no-ops | PASS — `MapSet.member?(active_provider_ids, provider_id)` guard in handler |
| C3 | Expired program — `active_provider_ids` excludes it | PASS — MapSet built from `active_programs` only |
| C4 | Idempotent conversation creation — clicking twice returns same conversation | PASS — `find_or_create_conversation` checks for existing before creating |
| C5 | Provider user resolution failure — `{:error, :not_found}` collapses to generic flash | PASS — catch-all `{:error, _}` branch |

## Auto-Fixes Applied
None

## Issues Filed
None

## Recommendations
- **Manual UI verification needed**: Playwright MCP is not configured for this project. Test the following flows manually in the browser with a seed parent account:
  1. Log in as a parent with an active enrollment
  2. Navigate to `/dashboard` → confirm "Contact Provider" button appears on active cards
  3. Click the button → confirm navigation to `/messages/:uuid` (not `/messages`)
  4. Click again on the same card → confirm same conversation URL (idempotent)
  5. Log in as a free-tier parent → confirm flash error on click
- **Tidewave MCP setup**: Add Tidewave to `.mcp.json` at project root to enable full backend verification in future test-drives. See CLAUDE.md for configuration reference.
