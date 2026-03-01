# Test Drive Report - 2026-03-01

## Scope

- **Mode:** branch (`git diff main...HEAD`)
- **Branch:** `bug/render-svg`
- **Files changed:** 27
- **Routes affected:** `/` (home), `/programs`, `/programs/:id`
- **Components affected:** `feature_card`, `program_card_simple`, `program_card`, `empty_state`

## Summary

Branch replaces broken `icon_path` (raw SVG d-attribute strings, nil in prod) with heroicon components derived from program category via `ProgramPresenter.icon_name/1`. All backend and UI checks pass. No bugs found.

## Backend Checks

### Passed

- **`icon_name/1` mapping:** All 7 defined categories return correct heroicons:
  - `sports` → `hero-trophy`
  - `arts` → `hero-paint-brush`
  - `music` → `hero-musical-note`
  - `education` → `hero-academic-cap`
  - `life-skills` → `hero-light-bulb`
  - `camps` → `hero-fire`
  - `workshops` → `hero-wrench-screwdriver`
- **`icon_name/1` fallback:** `nil` → `hero-academic-cap` (silent); unknown strings → `hero-academic-cap` + `Logger.warning`
- **ProgramSchema:** `icon_path` removed from schema fields
- **ProgramListingSchema:** `icon_path` removed from schema fields
- **Domain model (`Program`):** No `icon_path` reference
- **Projections:** `@shared_fields` and `@update_fields` exclude `:icon_path`; comment on line 266 explains removal rationale
- **SQL spot-check:** `SELECT icon_path FROM programs LIMIT 5` → all nil (column exists, no migration needed)
- **Server logs:** No warnings or errors related to unrecognized categories
- **Data flow verified:**
  - `HomeLive` calls `ProgramPresenter.icon_name(program.category)` directly on stream items
  - `ProgramsLive` calls `ProgramPresenter.icon_name(program.category)` in `program_to_map/2`
  - `ProgramDetailLive` assigns `program_icon_name: ProgramPresenter.icon_name(program.category)`

### Issues Found

None.

### Notes

- `to_card_view/1` only matches `%Program{}`, not `%ProgramListingSchema{}`. This is not a bug — no LiveView code path passes a listing to `to_card_view`. The function is used for provider dashboard contexts where domain `Program` entities are available.

## UI Checks

### Pages Tested

| Route | Status | Notes |
|---|---|---|
| `/` (home) | PASS | Featured cards show heroicons; "Why Klass Hero?" feature cards render `hero-shield-check`, `hero-calendar-days`, `hero-user-group` |
| `/programs` | PASS | All 19 program cards show category-based icons; filter pills work; no empty state triggered |
| `/programs/:id` (Life Skills Workshop) | PASS | Hero section icon (`hero-light-bulb`) renders in backdrop-blur circle; schedule, pricing, team all correct |

### Responsive Check (375x667)

| Page | Status | Notes |
|---|---|---|
| `/` (home) | PASS | Icons visible, layout stacks to single column, trending tags scroll horizontally |
| `/programs` | PASS | Cards stack to single column, filter pills scroll horizontally, icons render at correct size |

### Issues Found

None.

### Console Warnings

- `LiveView asset version mismatch` — pre-existing, unrelated to this branch (JS assets not recompiled after server code change)

## Auto-Fixes Applied

None needed.

## Screenshots

- `docs/reports/screenshots/home-desktop-2026-03-01.png` — Home page (desktop, full page)
- `docs/reports/screenshots/programs-desktop-2026-03-01.png` — Programs page (desktop, viewport)
- `docs/reports/screenshots/program-detail-desktop-2026-03-01.png` — Program detail (desktop, viewport)
- `docs/reports/screenshots/home-mobile-2026-03-01.png` — Home page (mobile 375x667, full page)
- `docs/reports/screenshots/programs-mobile-2026-03-01.png` — Programs page (mobile 375x667, viewport)

## Recommendations

None — branch is clean and ready for merge.
