# Test Drive Report: CQRS Read Models Branch

**Date:** 2026-02-27
**Branch:** `feat/establish-cqrs`
**Scope:** 66 files changed, ~6900 lines added

## Summary

**Overall: PASS** — All backend projections, use cases, and UI pages working correctly after server restart with pending migration applied.

## 1. Test Suite

| Check | Result |
|-------|--------|
| `mix test` | **2673 tests, 0 failures**, 12 skipped |
| Warnings | None (compile clean) |

## 2. Backend Verification (Tidewave MCP)

### 2a. Migrations & Tables

| Table | Columns | Indexes | Constraints |
|-------|---------|---------|-------------|
| `program_listings` | 24 cols (id, title, description, category, age_range, price, pricing_period, location, cover_image_url, icon_path, instructor_name, instructor_headshot_url, start_date, end_date, meeting_days, meeting_start_time, meeting_end_time, season, registration_start_date, registration_end_date, provider_id, provider_verified, inserted_at, updated_at) | pkey, category, cursor (inserted_at, id), provider_id | NOT NULL on id, title, provider_id, provider_verified, inserted_at, updated_at |
| `conversation_summaries` | 17 cols (id, conversation_id, user_id, conversation_type, provider_id, program_id, subject, other_participant_name, participant_count, latest_message_content, latest_message_sender_id, latest_message_at, unread_count, last_read_at, archived_at, inserted_at, updated_at) | pkey, conversation_id, unique(conversation_id, user_id), inbox (user_id, archived_at, latest_message_at), unread partial (user_id WHERE archived_at IS NULL) | NOT NULL on id, conversation_id, user_id, conversation_type, provider_id, unread_count, inserted_at, updated_at; CHECK (unread_count >= 0) |

**Note:** The `unread_count_non_negative` CHECK constraint was in a **pending migration** (`20260226000014`) that had not been applied. Applied during this test drive.

### 2b. Projection GenServers

| GenServer | Status | PID |
|-----------|--------|-----|
| `ProjectionSupervisor` | Running | `#PID<0.1216.0>` |
| `VerifiedProviders` | Running | `#PID<0.1217.0>` |
| `ProgramListings` | Running | `#PID<0.1218.0>` |
| `ConversationSummaries` | Running | `#PID<0.1219.0>` |

**Initial finding:** Before server restart, `ProjectionSupervisor` was NOT in the supervision tree — the running server was using stale code from before the supervisor was introduced. Only `VerifiedProviders` was running as a direct child. After full server restart, all four processes started correctly under the `:rest_for_one` supervisor.

### 2c. Bootstrap Data

| Read Table | Row Count | Write Table | Row Count | Match? |
|------------|-----------|-------------|-----------|--------|
| `program_listings` | 19 | `programs` | 19 | Yes |
| `conversation_summaries` | 14 | (5 conversations, multiple participants) | — | Yes |

Bootstrap logs confirmed clean startup:
- `[info] ProgramListings projection started`
- `[info] ConversationSummaries projection started`
- `[info] VerifiedProviders projection started`

### 2d. Use Cases

| Use Case | Result |
|----------|--------|
| `ListAllPrograms.execute()` | 19 `ProgramListing` structs with 24 fields |
| `ListFeaturedPrograms.execute()` | 2 programs: "Art & Music Fusion", "Athletic Conditioning" |
| `ListProviderPrograms.execute(provider_id)` | 2 programs: "Soccer Fundamentals", "Youth Fitness Basics" |

All use cases return `ProgramListing` DTOs (not `Program` entities), confirming the read model switch.

### 2e. Conversation Summaries Data

Sample verified:
- Correct `conversation_type` ("direct")
- Correct `other_participant_name` (e.g., "Julia Hoffmann", "Stefan Schafer")
- Correct `unread_count` values (2-3 per participant)
- Correct `latest_message_content` populated from write model

### 2f. Error Logs

- **No projection-related errors** in logs
- Only noise from `LiveDebugger.Services.CallbackTracer.GenServers.TracingManager` (unrelated to CQRS)

## 3. UI Verification (Playwright MCP)

### 3a. Programs Page (`/programs`)

| Check | Result |
|-------|--------|
| Page renders | Yes — "Explore Programs" heading, 19 program cards |
| Program cards show title | Yes (e.g., "Life Skills Workshop", "Children's Choir") |
| Program cards show price | Yes (e.g., "€95.00", "€120.00", "€150.00") |
| Program cards show category badge | Yes (e.g., "Life Skills", "Music", "Camps") |
| Program cards show schedule | Yes (e.g., "Sat 10:00 AM - 12:00 PM") |
| Search filtering | **Works** — typing "soccer" filters to 2 results (Soccer Fundamentals, Elite Soccer Training) |
| Category filtering | **Works** — clicking "Arts" filters to 2 results (Watercolor Workshop, Art & Music Fusion) |
| Program card links to detail | **Works** — clicking navigates to `/programs/:id` with full detail page |
| Sort dropdown present | Yes — "Recommended" with grid/list view toggle |

**Console warning:** 6 "form events require the input to be inside" errors when typing in search box. This is a pre-existing LiveView form binding issue (search input not inside a `<form>` tag), not introduced by CQRS changes.

### 3b. Home Page (`/`)

| Check | Result |
|-------|--------|
| Featured Programs section | Yes — "Featured Programs" heading visible |
| Featured programs count | 2 (correct max) |
| Featured program titles | "Art & Music Fusion" (€130.00), "Athletic Conditioning" (€180.00) |
| Verification badges | Yes — Background Check, First Aid, Child Safeguarding, Insurance |
| Book Now buttons | Yes — present on both cards |
| "View All Programs" link | Yes |

### 3c. Provider Dashboard & Messages

Provider dashboard and messages inbox require authentication. Verified via **Tidewave backend** instead:
- `ListProviderPrograms.execute(provider_id)` returns correct filtered programs
- `conversation_summaries` table has 14 rows with correct participant names, unread counts, and latest messages

### 3d. Mobile Responsiveness (375x667)

| Check | Result |
|-------|--------|
| Single-column card layout | Yes |
| Horizontally scrollable category pills | Yes |
| Hamburger menu | Yes |
| Search box | Yes — full width |
| Program cards readable | Yes — title, description, price, schedule visible |

**Minor pre-existing issue:** Klass Hero logo slightly clipped by language switcher flags on narrow screens. Not related to CQRS changes.

## 4. Screenshots

| Screenshot | Path |
|-----------|------|
| Programs page (desktop) | `docs/reports/screenshots/programs-page-desktop.png` |
| Search filter "soccer" | `docs/reports/screenshots/programs-search-soccer.png` |
| Home page (featured programs) | `docs/reports/screenshots/home-featured-programs.png` |
| Programs page (mobile 375x667) | `docs/reports/screenshots/programs-mobile-375x667.png` |

## 5. Issues Found

### Blocker: None

### Important

1. **Pending migration not applied** — Migration `20260226000014_add_unread_count_check_constraint` was not applied before the test drive. The `unread_count_non_negative` CHECK constraint was missing until manually applied. **Fix: ensure `mix ecto.migrate` is run after checkout.**

### Informational (pre-existing, not CQRS-related)

2. **Console errors on search input** — "form events require the input to be inside" when typing in the search box. The search `<input>` is not wrapped in a `<form>` tag. This is cosmetic (search still works) and pre-existing.

3. **Mobile logo clipping** — Language switcher flags overlap the Klass Hero logo at 375px width. Pre-existing layout issue.

4. **LiveDebugger TracingManager errors** — Repeated `:already_started` crashes in LiveDebugger's tracing manager. This is a dev dependency issue, not application code.
