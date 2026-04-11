# Perf Improver Memory — klass-hero

## Last Updated
2026-04-11

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
| 2026-04-11 | T4, T3, T7 | T4: PR #622 merged; PR #628 (parallelize DashboardLive) open + CI passing. T3: PR submitted — push SQL LIMIT in ListFeaturedPrograms via list_active_limited/1; home page query drops from N rows → 2 rows. T7: Updated April 2026 monthly summary. |
| 2026-04-10 | T3, T7 | T3: PR submitted — push SQL LIMIT in ListFeaturedPrograms; adds list_active_limited/1 port callback + repo impl; home page query goes from N rows → 2 rows. T7: Updated April 2026 monthly summary. |
| 2026-04-09 | T4, T2, T3, T7 | T4: PR #622 (parallelize SessionsLive mount) confirmed open + CI clean. T2: Identified over-fetching in ListFeaturedPrograms — maintainer noted Enum.take(2) on full catalog; add SQL LIMIT + composite index. T3: New PR submitted — parallelize Family.get_children + load_family_programs in parent DashboardLive.mount; saves ~5–10ms per parent /dashboard load. T7: Updated April 2026 monthly summary. |
| 2026-04-08 | T4, T5, T3, T7 | T4: PR #609 confirmed merged. T5: Commented on #478 (ETS cache, read_concurrency flag + warm-up race advice). T3: PR #622 submitted — parallelize list_programs_for_provider + list_provider_sessions in SessionsLive.mount; saves ~5–15ms per page load. T7: Updated April 2026 monthly summary. |
| 2026-04-07 | T4, T2, T3, T7 | T4: PR #602 confirmed merged (batch absent). T2: Found redundant provider DB query in mount_conversation_show — get_identity_id_for_provider + get_provider_profile both hit providers table for same provider_id. T3: PR #609 submitted — merge into single resolve_provider_info/1 call; saves 1 DB round-trip per conversation open. T7: Updated April 2026 monthly summary. |
| 2026-04-06 | T3, T7 | T3: Implemented N+1 fix for CompleteSession.mark_remaining_as_absent — new mark_absent_batch/1 callback + update_all impl; reduces 1+2N queries to 2 per session completion. PR submitted (merged as #602). T7: Updated April 2026 monthly summary. |
| 2026-04-05 | T5, T2, T4, T7 | T4: PR #592 CI clean. T2: Identified N+1 in CompleteSession.mark_remaining_as_absent. T5: Commented on #515 with PubSub fan-out measurement guidance. T7: Updated April 2026 monthly summary. |
| 2026-04-04 | T4, T2, T3, T7 | T4: PR #583 confirmed merged. T2: Confirmed N+1 in StaffAssignmentHandler. T3: Created PR #592 perf-assist/batch-staff-participant-inserts. T7: Updated April 2026 monthly summary. |
| 2026-04-03 | T1, T2, T6, T3, T7 | T1: Commands unchanged. T6: No new infra gaps. T2: Found MessagingLiveHelper redundant conversation fetch. T3: PR merged as #583. T7: Closed March 2026 (#284), created April 2026 monthly summary. |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-04-03
- T2 (Identify opportunities): 2026-04-09
- T3 (Implement improvement): 2026-04-11
- T4 (Maintain PRs): 2026-04-11
- T5 (Comment on issues): 2026-04-08
- T6 (Measurement infra): 2026-04-03
- T7 (Activity summary): 2026-04-11

## Optimization Backlog (prioritized)
1. **[MERGED]** N+1 in DashboardLive — PR #290 merged ✓
2. **[MERGED]** Missing LiveView telemetry — PR #305 merged ✓
3. **[MERGED]** Parallelize ProgramDetailLive mount — PR #346 merged ✓
4. **[CLOSED/REJECTED]** Redundant DB query in ParticipationHistoryLive — PR #320 closed without merge 2026-03-09
5. **[MERGED]** Duplicate staff query in provider dashboard mount — PR #366 merged ✓
6. **[MERGED]** Redundant count_active_enrollments_batch — PR #382 merged ✓
7. **[MERGED]** Parallelize list_programs_for_provider + fetch_staff_members — PR #393 merged ✓
8. **[MERGED]** Duplicate get_parent_by_identity in DashboardLive.mount — PR #410 merged ✓
9. **[MERGED]** Duplicate get_parent_by_identity in BookingLive.mount — PR #419 merged ✓
10. **[CLOSED/REJECTED]** users.inserted_at index — PR #428 closed 2026-03-15 ("< 50 users, overkill")
11. **[MERGED]** Skip redundant conversations.get_by_id in SendMessage (ReplyPrivatelyToBroadcast) — PR #441 merged ✓
12. **[MERGED]** Pass conversation to SendMessage in MessagingLiveHelper hot path — PR #583 merged 2026-04-03 ✓
13. **[MERGED]** N+1 in StaffAssignmentHandler.add_staff_to_existing_conversations — PR #592 merged 2026-04-05 ✓
14. **[MERGED]** N+1 in CompleteSession.mark_remaining_as_absent — PR #602 merged 2026-04-06 ✓
15. **[MERGED]** Redundant providers table query in mount_conversation_show — PR #609 merged 2026-04-07 ✓
16. **[MERGED]** Parallelize list_programs_for_provider + list_provider_sessions in SessionsLive.mount — PR #622 merged 2026-04-11 ✓
17. **[IN REVIEW]** Parallelize Family.get_children + load_family_programs in parent DashboardLive.mount — PR #628, submitted 2026-04-09
18. **[IN REVIEW]** Over-fetching in ListFeaturedPrograms.execute/0 — list_active_limited/1 with SQL LIMIT; PR submitted 2026-04-11 (number pending)
19. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries
20. **[LOW]** program_sessions.status index — verify query patterns first
21. **[PLANNED]** ETS projection cache for program→provider ACL resolution — issue #478, maintainer-designed

## Backlog Cursor
- Next run: T1 (commands, last run 2026-04-03) + T6 (measurement infra, last run 2026-04-03) + T5 (comment on issues, last run 2026-04-08)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — includes LiveView metrics
- Maintainer is conservative about DB indexes for write-heavy tables AND small tables
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Maintainer is active and merges PRs quickly
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally
- SendMessage.execute accepts optional :conversation opt — when provided, skips the conversations.get_by_id fetch
- Index PRs pattern: only accepted when backed by production Honeycomb evidence AND non-trivial table size
- add_batch/2 on ParticipantRepository handles (one conversation, many users) via insert_all
- add_to_conversations_batch/2 (PR #592, merged) handles (one user, many conversations) via insert_all
- mark_absent_batch/1 (PR #602, merged) handles bulk absent-marking via update_all WHERE status=:registered AND id IN (:ids)
- Provider.get_provider_profile returns ProviderProfile with identity_id AND business_name
- Task.async/await parallel pattern is accepted by maintainer (used in DashboardLive PR #393, SessionsLive PR #620)
- ETS table for read-heavy cross-context caches: use [:set, :public, :named_table, {:read_concurrency, true}]
- list_active/0 in ProgramListingsRepository is left unchanged; list_active_limited/1 adds LIMIT capability as a separate port callback
- PR #625 "hide expired programs from home page featured section" added end_date filter — but list_active() still had no LIMIT; list_active_limited/1 PR submitted 2026-04-11

## Active PRs
- `perf-assist/parallelize-dashboard-children-programs-0ad9699a12b5c639` — PR #628, created 2026-04-09; parallelize Family.get_children + load_family_programs in parent DashboardLive.mount; saves ~5–10ms per page load; CI passing
- `perf-assist/limit-featured-programs-query` — PR submitted 2026-04-11 (number pending); push SQL LIMIT in ListFeaturedPrograms via list_active_limited/1; home page query drops from N rows → 2 rows

## Completed Work
- PR #622 (parallelize list_programs_for_provider + list_provider_sessions in SessionsLive) — merged 2026-04-11 ✓
- PR #609 (eliminate redundant provider query in conversation show) — merged 2026-04-07 ✓
- PR #602 (N+1 in CompleteSession — batch update via update_all) — merged 2026-04-06 ✓
- PR #592 (N+1 in StaffAssignmentHandler — batch insert via insert_all) — merged 2026-04-05 ✓
- PR #583 (pass conversation to MessagingLiveHelper SendMessage) — merged 2026-04-03 ✓
- PR #441 (skip conversation fetch in SendMessage for ReplyPrivatelyToBroadcast) — merged 2026-03-16 ✓
- PR #419 (eliminate duplicate parent lookup in BookingLive.mount) — merged 2026-03-15 ✓
- PR #410 (eliminate duplicate parent lookup in DashboardLive.mount) — merged 2026-03-14 ✓

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
