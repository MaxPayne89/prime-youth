# Perf Improver Memory — klass-hero

## Last Updated
2026-04-03

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
| 2026-04-03 | T1, T2, T6, T3, T7 | T1: Commands unchanged. T6: Maintainer already enabled Elixir 1.20 interpreted compilation + parallel dep builds (PR merged 2026-04-01). T2: Found MessagingLiveHelper.handle_send_message doesn't pass conversation to SendMessage — redundant DB fetch on every message send. T3: Created PR perf-assist/pass-conversation-to-send-message-in-live-helper — passes socket.assigns.conversation to Messaging.send_message hot path; saves 1 DB round-trip per message send across all 3 LiveViews. T7: Closed March 2026 (#284), created April 2026 monthly summary. |
| 2026-03-16 | T5, T3, T7 | T5: Commented on #431 (SQL-level fix for 100-message dedup ceiling). T3: Created PR perf-assist/skip-conversation-fetch-in-send-message — adds optional :conversation opt to SendMessage; ReplyPrivatelyToBroadcast passes direct_conversation to skip redundant DB fetch; closes #430; merged 2026-03-16 as PR #441. T4: PR #428 (users.inserted_at) closed by maintainer 2026-03-15 "< 50 users, overkill". |
| 2026-03-15 | T3, T4, T7 | T4: PR #419 (BookingLive duplicate parent lookup) confirmed merged by maintainer 2026-03-15. Issue #394 closed as completed. T3: Created PR perf-assist/add-inserted-at-index-to-users — PR #428, closed by maintainer 2026-03-15 ("< 50 users, overkill"). |
| 2026-03-14 | T4, T2, T3, T7 | T4: PR #410 (dashboard parent lookup) confirmed merged 2026-03-14. T2: Issue #394 (booking duplicate lookup) still open — booking half unresolved. Issue #396 (admin pagination P95 109ms) open, Daily QA confirmed missing users.inserted_at index. T3: Created PR perf-assist/eliminate-duplicate-parent-lookup-in-booking-live-2a29bb70 — eliminates duplicate get_parent_by_identity in BookingLive.mount; saves 1 DB round-trip per booking page load. |
| 2026-03-13 | T1, T6, T3, T7 | T1: Commands revalidated — no changes. T6: Discovered duplicate Family.get_parent_by_identity call in parent DashboardLive.mount (called inside get_children_for_current_user + again in try block). T3: Created PR perf-assist/eliminate-duplicate-parent-lookup-in-parent-dashboard (PR #410) — merged 2026-03-14. |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-04-03
- T2 (Identify opportunities): 2026-04-03
- T3 (Implement improvement): 2026-04-03
- T4 (Maintain PRs): 2026-03-16
- T5 (Comment on issues): 2026-03-16
- T6 (Measurement infra): 2026-04-03
- T7 (Activity summary): 2026-04-03

## Optimization Backlog (prioritized)
1. **[MERGED]** N+1 in DashboardLive — PR #290 merged ✓
2. **[MERGED]** Missing LiveView telemetry — PR #305 merged ✓
3. **[MERGED]** Parallelize ProgramDetailLive mount — PR #346 merged ✓
4. **[CLOSED/REJECTED]** Redundant DB query in ParticipationHistoryLive — PR #320 closed without merge 2026-03-09
5. **[MERGED]** Duplicate staff query in provider dashboard mount — PR #366 merged ✓
6. **[MERGED]** Redundant count_active_enrollments_batch in build_enrollment_data — PR #382 merged ✓
7. **[MERGED]** Parallelize list_programs_for_provider + fetch_staff_members in provider dashboard — PR #393 merged ✓
8. **[MERGED]** Duplicate get_parent_by_identity in parent DashboardLive.mount — PR #410 merged ✓
9. **[MERGED]** Duplicate get_parent_by_identity in BookingLive.mount — PR #419 merged 2026-03-15 ✓
10. **[CLOSED/REJECTED]** users.inserted_at index for admin accounts pagination — PR #428 closed 2026-03-15 ("< 50 users, overkill"); issue #396 still open
11. **[MERGED]** Skip redundant conversations.get_by_id in SendMessage (ReplyPrivatelyToBroadcast) — PR #441 merged 2026-03-16 ✓
12. **[CLOSED]** system_note_exists? 100-message dedup ceiling — issue #431 closed 2026-03-16 by maintainer ✓
13. **[IN REVIEW]** Pass conversation to SendMessage in MessagingLiveHelper hot path — PR submitted 2026-04-03 (branch: perf-assist/pass-conversation-to-send-message-in-live-helper); saves 1 DB round-trip per message send across all 3 messaging LiveViews
14. **[LOW]** N+1 in StaffAssignmentHandler.add_staff_to_existing_conversations — fires N inserts (one per conversation) instead of 1 insert_all when staff assigned to program; background event handler, low urgency; would need new port callback add_to_conversations_batch(user_id, conversation_ids)
15. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries (low urgency)
16. **[LOW]** program_sessions.status index — Maintainer conservative on indexes — verify query patterns first

## Backlog Cursor
- Next run: T4 (check on new messaging PR), T5 (scan for new perf issues), and re-check open issues for opportunities after recent PR #571 feature (staff messaging)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — includes LiveView metrics (merged PR #305)
- Maintainer is conservative about DB indexes for write-heavy tables AND small tables ("< 50 users, overkill" — closed PR #428)
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- `get_by_ids` pattern now in ProgramCatalog (from PR #290)
- `live_debugger` and `phoenix_live_dashboard` both installed in deps
- Maintainer is active and merges PRs quickly (PRs #290, #305, #346, #366, #382, #393, #410, #419, #441 all merged promptly)
- `filter_programs` is intentionally in-memory (word-boundary matching; DB-level impractical without FTS)
- `conversation_summaries` table already denormalizes `unread_count` and `latest_message_at` — backlog item (conversation list) is already addressed at the data layer
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally
- Pattern for eliminating duplicate parent lookups: call `Family.get_parent_by_identity` once at top of mount; use parent struct in `assign_booking_usage_info/2` (2-arity taking parent); inline `Entitlements.monthly_booking_cap + Enrollment.count_monthly_bookings` instead of calling `Enrollment.get_booking_usage_info(identity_id)` which internally re-fetches the parent
- Issue #394 (duplicate parent lookups) closed as completed 2026-03-15 (both dashboard + booking fixed)
- Index PRs pattern: only accepted when backed by production Honeycomb evidence AND non-trivial table size; "< 50 users" = rejected
- SendMessage.execute accepts optional :conversation opt — when provided, skips the conversations.get_by_id fetch in verify_broadcast_send_permission/4 (avoids double-fetch from callers that already hold the conversation)
- MessagingLiveHelper.handle_send_message uses socket.assigns.conversation — always safe to pass as :conversation opt (ID invariant: extracted from same struct)
- Maintainer added Elixir 1.20 interpreted compilation (module_definition: :interpreted) and parallel dep builds (MIX_OS_DEPS_COMPILE_PARTITION_COUNT=4) in 2026-04-01 — build time improvement already shipped
- PR #571 (staff messaging parents) introduced StaffAssignmentHandler — has N+1 in add_staff_to_existing_conversations (N inserts vs 1 insert_all); background event, low urgency

## Active PRs
- `perf-assist/pass-conversation-to-send-message-in-live-helper` — created 2026-04-03; passes pre-fetched conversation to SendMessage in MessagingLiveHelper hot path; saves 1 DB round-trip per message send

## Completed Work
- PR #441 (skip conversation fetch in SendMessage for ReplyPrivatelyToBroadcast) — merged 2026-03-16 by maintainer
- PR #419 (eliminate duplicate parent lookup in BookingLive.mount) — merged 2026-03-15 by maintainer
- PR #428 (users.inserted_at index) — closed 2026-03-15 by maintainer ("< 50 users, overkill")
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
