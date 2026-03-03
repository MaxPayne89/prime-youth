# Test Drive Report - 2026-03-03

## Scope
- Mode: branch (`git diff main...HEAD`)
- Files changed: 12 (6 source, 2 docs, 4 tests)
- Routes affected: `/programs`, `/programs/:id`, `/provider/dashboard`
- Branch: `worktree-bug/196-program-cover-image`

## Backend Checks

### Passed
- **Schema field**: `cover_image_url` field exists on `ProgramSchema` (confirmed via `project_eval`)
- **Programs table**: `cover_image_url` column present in `programs` table (all nil in seed data)
- **Projection table**: `cover_image_url` column present in `program_listings` projection table
- **Flash kind**: `:warning` added to `core_components.ex` flash component kind values (line 26)
- **Flash group**: Warning flash slot added in `layouts.ex` (line 29)
- **Upload flow**: `maybe_flash_cover_warning/2` correctly pattern-matches `:upload_error` vs other results
- **Non-blocking save**: `save_program` always proceeds to create/update regardless of upload result
- **No application warnings**: Zero warning-level logs during UI test-drive

### Issues Found
- None

## UI Checks

### Pages Tested

#### `/programs` (Programs Listing)
- **Desktop (1280x720)**: PASS
  - Gradient fallback cards render correctly with icon, gradient, and category badge
  - Cover image card renders `<img>` with `loading="lazy"` and correct alt text
  - Category badges overlay correctly on both cover image and gradient cards
  - Screenshot: `programs-listing-desktop.png`, `programs-card-cover-image.png`
- **Mobile (375x667)**: PASS
  - Cards stack single-column properly
  - Category pills horizontally scrollable
  - Screenshot: `programs-listing-mobile.png`

#### `/programs/:id` (Program Detail)
- **With cover image (desktop)**: PASS
  - `#program-hero-image` renders with cover image URL
  - Gradient overlay (`from-black/60`) provides text readability
  - Title, schedule, "No hidden fees" badge positioned at bottom of hero
  - Back button functional — navigates to `/programs`
  - Screenshot: `program-detail-cover-image.png`
- **Without cover image (desktop)**: PASS
  - Gradient hero with centered icon renders
  - Title, schedule, badge positioned below icon
  - No `#program-hero-image` element present (correct)
  - Screenshot: `program-detail-gradient-fallback.png`
- **With cover image (mobile)**: PASS
  - Hero area scales properly to `h-64`
  - Info overlay readable, buttons stack vertically
  - Screenshot: `program-detail-cover-mobile.png`
- **Without cover image (mobile)**: PASS
  - Gradient hero renders cleanly on small viewport
  - Screenshot: `program-detail-gradient-mobile.png`

#### `/provider/dashboard` (Provider Dashboard)
- **Flash infrastructure**: PASS (verified via test suite — warning flash renders in `#flash-group`)
- **Upload flow**: PASS (verified via test suite — program saves with/without cover image, warning flash on upload error)

### Issues Found
- None

## Test Results
- **Component tests**: 8 passed (program_card_cover_image_test.exs)
- **Program detail tests**: 23 passed (program_detail_live_test.exs)
- **Programs listing tests**: 21 passed (programs_live_test.exs)
- **Provider dashboard tests**: 20 passed (dashboard_program_creation_test.exs)
- **Full suite**: 2760 tests, 0 failures, 12 skipped

## Pre-commit
- `mix precommit`: PASS (compile with warnings-as-errors, format, test all pass)

## Auto-Fixes Applied
- None needed

## Recommendations
- None — all changes are working correctly. Branch is ready for PR.
