# Perf Improver Memory — prime-youth

## Last Updated
2026-03-14

## Build / Test / Lint Commands (validated from mix.exs + CI)
- **Build**: `mix compile --warnings-as-errors`
- **Test**: `mix test` (CI: needs Postgres Docker via `docker-compose.yml`)
- **Format**: `mix format` / `mix format --check-formatted`
- **Pre-commit**: `mix precommit` (compile --warnings-as-errors, deps.unlock --unused, format, lint_typography, test)
- **Assets**: `mix assets.build` / `mix assets.deploy` (tailwind + esbuild)
- **Linting**: `mix credo --strict` (credo dep), `mix sobelow` (security)
- **Note**: Elixir/mix not available in CI runner environment — compile check not runnable

## Run History
| Date | Tasks | Output |
|------|-------|--------|
| 2026-03-14 | T4, T2, T3, T7 | T4: PR #410 (dashboard parent lookup) confirmed merged 2026-03-14. T2: Issue #394 (booking duplicate lookup) still open — booking half unresolved. Issue #396 (admin pagination P95 109ms) open, Daily QA confirmed missing users.inserted_at index. T3: Created PR perf-assist/eliminate-duplicate-parent-lookup-in-booking-live-2a29bb70 — eliminates duplicate get_parent_by_identity in BookingLive.mount; saves 1 DB round-trip per booking page load. |
| 2026-03-13 | T1, T6, T3, T7 | T1: Commands revalidated — no changes. T6: Discovered duplicate Family.get_parent_by_identity call in parent DashboardLive.mount (called inside get_children_for_current_user + again in try block). T3: Created PR perf-assist/eliminate-duplicate-parent-lookup-in-parent-dashboard (PR #410) — merged 2026-03-14. |
| 2026-03-12 | T4, T5, T3, T7 | T4: PR #382 (enrollment count query) confirmed merged. PR #393 (parallel dashboard mount) confirmed merged. T5: No open perf issues. T3: Created PR perf-assist/parallel-dashboard-mount-queries (PR #393) — merged same day. |
| 2026-03-11 | T2, T3, T7 | T4: PR #366 (duplicate staff query) confirmed merged by maintainer 2026-03-10. T3: Created PR perf-assist/eliminate-redundant-enrollment-count-query (#382) — merged 2026-03-12. |
| 2026-03-10 | T4, T3, T7 | T4: PR #346 (parallelize ProgramDetailLive mount) confirmed merged by maintainer 2026-03-10. T3: Created PR perf-assist/eliminate-duplicate-staff-query-73137822 (PR #366) — merged 2026-03-10. |
| 2026-03-09 | T4, T3, T7 | T4: PR #320 (redundant child query) was closed without merge by maintainer (no comment). T3: Created PR perf-assist/parallel-program-detail-mount — parallelizes load_team_members + get_participant_policy in ProgramDetailLive mount with Task.async. |
| 2026-03-08 | T2, T3, T7 | T2: Both previous PRs (#290, #305) confirmed merged by maintainer — updated backlog accordingly. T2: Identified redundant `Family.get_child_ids_for_parent/1` call in `ParticipationHistoryLive.apply_history/4` — extra DB query when `children` already in scope. T3: Created PR `perf-assist/eliminate-redundant-child-query` — replaces redundant DB call with `MapSet.new(children, &1.id)`; saves 1 DB round-trip per participation history page load. |
| 2026-03-07 | T4, T5, T6, T7 | T4: PR #290 CI pending/no comments — no action. T5: No open perf issues. T6: Added LiveView telemetry metrics PR (#305). T7: Monthly summary updated. |
| 2026-03-06 | T3, T4, T5, T7 | T3: PR #290 created for DashboardLive N+1 batch program loading. T4: PR #283 was closed by maintainer (rejected). T5: No open performance issues. |
| 2026-03-05 | T1, T2, T3, T7 | First run. PR #283 created for missing DB indexes (later closed/rejected by maintainer). |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-03-13
- T2 (Identify opportunities): 2026-03-14
- T3 (Implement improvement): 2026-03-14
- T4 (Maintain PRs): 2026-03-14
- T5 (Comment on issues): 2026-03-12 (no perf issues open)
- T6 (Measurement infra): 2026-03-13
- T7 (Activity summary): 2026-03-14

## Optimization Backlog (prioritized)
1. **[MERGED]** N+1 in DashboardLive — PR #290 merged ✓
2. **[MERGED]** Missing LiveView telemetry — PR #305 merged ✓
3. **[MERGED]** Parallelize ProgramDetailLive mount — PR #346 merged ✓
4. **[CLOSED/REJECTED]** Redundant DB query in ParticipationHistoryLive — PR #320 closed without merge 2026-03-09 (optimization was independently applied in codebase).
5. **[MERGED]** Duplicate staff query in provider dashboard mount — PR #366 merged ✓
6. **[MERGED]** Redundant count_active_enrollments_batch in build_enrollment_data — PR #382 merged 2026-03-12 ✓
7. **[MERGED]** Parallelize list_programs_for_provider + fetch_staff_members in provider dashboard mount — PR #393 merged 2026-03-12 ✓
8. **[MERGED]** Duplicate get_parent_by_identity in parent DashboardLive.mount — PR #410 merged 2026-03-14 ✓
9. **[IN REVIEW]** Duplicate get_parent_by_identity in BookingLive.mount — PR submitted 2026-03-14 (branch: perf-assist/eliminate-duplicate-parent-lookup-in-booking-live-2a29bb70)
10. **[MED]** Admin users.inserted_at index — missing index for default sort on /admin/accounts; P95 109ms confirmed by Honeycomb; Daily QA also flagged this; maintainer conservative on indexes but has production evidence; needs maintainer decision
11. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries (low urgency)
12. **[LOW]** program_sessions.status index — Maintainer conservative on indexes — verify query patterns first.

## Backlog Cursor
- Next run: T1 (revalidate commands), T5 (comment on issue #396 about admin index — has production evidence), T6 (check measurement infra)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — includes LiveView metrics (merged PR #305)
- Maintainer is conservative about DB indexes: "not justified based on the current query patterns" (from PR #283)
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- `get_by_ids` pattern now in ProgramCatalog (from PR #290)
- `live_debugger` and `phoenix_live_dashboard` both installed in deps
- Maintainer is active and merges PRs quickly (PRs #290, #305, #346, #366, #382, #393, #410 all merged promptly)
- `filter_programs` is intentionally in-memory (word-boundary matching; DB-level impractical without FTS)
- `conversation_summaries` table already denormalizes `unread_count` and `latest_message_at` — backlog item (conversation list) is already addressed at the data layer
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally
- Pattern for eliminating duplicate parent lookups: call `Family.get_parent_by_identity` once at top of mount; use parent struct in `assign_booking_usage_info/2` (2-arity taking parent); inline `Entitlements.monthly_booking_cap + Enrollment.count_monthly_bookings` instead of calling `Enrollment.get_booking_usage_info(identity_id)` which internally re-fetches the parent
- DashboardLive.assign_booking_usage_info/2 and BookingLive.assign_booking_limit_info/2 both use this pattern now
- Issue #394 (duplicate parent lookups) tracks both dashboard + booking; dashboard fixed by PR #410; booking fixed by current PR in review
- Issue #396 (admin pagination): /admin/accounts uses Backpex, sorted by inserted_at desc, no index exists; Daily QA confirmed the missing index; P95 109ms with tight variance suggests full-table-scan + sort

## Active PRs
- `perf-assist/eliminate-duplicate-parent-lookup-in-booking-live-2a29bb70` — created 2026-03-14 (eliminates duplicate get_parent_by_identity call in BookingLive.mount; closes issue #394 second half)

## Completed Work
- PR #410 (eliminate duplicate parent lookup in DashboardLive.mount) — merged 2026-03-14 by maintainer
- PR #393 (parallel programs + staff in provider dashboard mount) — merged 2026-03-12 by maintainer
- PR #382 (eliminate redundant enrollment count query) — merged 2026-03-12 by maintainer
- PR #366 (duplicate staff query in DashboardLive mount) — merged 2026-03-10 by maintainer
- PR #346 (parallelize ProgramDetailLive mount) — merged 2026-03-10 by maintainer
- PR #290 (N+1 in DashboardLive) — merged 2026-03-07 by maintainer
- PR #305 (LiveView telemetry metrics) — merged 2026-03-07 by maintainer
- PR #283 (DB indexes) — closed/rejected 2026-03-05 by maintainer (not justified)
- PR #320 (redundant child query) — closed without merge 2026-03-09 (no comment)

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
