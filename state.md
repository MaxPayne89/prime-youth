# Perf Improver Memory — klass-hero

## Last Updated
2026-04-15

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
| 2026-04-15 | T3, T7 | T3: Re-created branch perf-assist/limit-featured-programs-sql (commit f8eb334); safeoutputs MCP unavailable prevented PR creation again. Monthly summary not updated (safeoutputs MCP unavailable). |
| 2026-04-14 | T4, T2, T3 | T4: No open perf-assist branches — all previous PRs merged/closed. T2: SQL LIMIT opt + StaffDashboardLive parallelization still unmerged. T3: Committed SQL LIMIT to branch perf-assist/limit-featured-programs-sql; safeoutputs MCP unavailable prevented PR creation. Monthly summary not updated (safeoutputs MCP unavailable). |
| 2026-04-12 | T1, T6, T5, T3, T7 | T1: Commands unchanged. T6: No new infra gaps. T5: #478 + #515 — no new comments. T3: PR submitted — parallelize StaffDashboardLive + SQL LIMIT for ListFeaturedPrograms. T7: Updated April 2026 monthly summary. |
| 2026-04-11 | T4, T3, T7 | T4: PR #622 merged; PR #628 open + CI passing. T3: SQL LIMIT PR submitted again. T7: Updated. |
| 2026-04-09 | T4, T2, T3, T7 | T3: PR #628 submitted — parallelize DashboardLive children+programs. T4: PR #622 CI clean. |
| 2026-04-08 | T4, T5, T3, T7 | T4: PR #609 merged. T5: Commented on #478. T3: PR #622 submitted — parallelize SessionsLive. |
| 2026-04-07 | T4, T2, T3, T7 | T3: PR #609 submitted — merge redundant provider query in conversation show. |
| 2026-04-06 | T3, T7 | T3: PR #602 submitted — N+1 in CompleteSession.mark_remaining_as_absent (update_all). |
| 2026-04-03–05 | T1-T7 | T3: PR #592 (N+1 in StaffAssignmentHandler), PR #583 (MessagingLiveHelper conversation pass-through). |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-04-12
- T2 (Identify opportunities): 2026-04-14
- T3 (Implement improvement): 2026-04-15
- T4 (Maintain PRs): 2026-04-14
- T5 (Comment on issues): 2026-04-12
- T6 (Measurement infra): 2026-04-12
- T7 (Activity summary): 2026-04-12

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
17. **[MERGED]** Parallelize Family.get_children + load_family_programs in parent DashboardLive.mount — PR #628, confirmed merged ✓
18. **[BRANCH READY, NEEDS PR]** Over-fetching in ListFeaturedPrograms.execute/0 — branch perf-assist/limit-featured-programs-sql (commit f8eb334); safeoutputs MCP unavailable twice (2026-04-14, 2026-04-15); push + create PR when MCP available
19. **[NEEDS PR]** Parallelize Provider.get_provider_profile + list_programs_for_provider in StaffDashboardLive.mount — still sequential; no branch yet
20. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries
21. **[LOW]** program_sessions.status index — verify query patterns first
22. **[PLANNED]** ETS projection cache for program→provider ACL resolution — issue #478, maintainer-designed
23. **[NEW]** Admin sessions live: list_providers_for_select + list_programs_for_select in mount are sequential and independent — could parallelize; admin-only page, lower priority

## Backlog Cursor
- Next run: T5 (comment on issues, last run 2026-04-12) + T6 (measurement infra, last run 2026-04-12)
- CRITICAL: Push branch perf-assist/limit-featured-programs-sql and create PR when safeoutputs MCP is available (tried twice — 2026-04-14 and 2026-04-15)

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
- trending_searches/0 is a hardcoded in-memory list — no DB call, not parallelizable
- safeoutputs MCP server was unavailable on 2026-04-14 AND 2026-04-15 runs — could not create PRs or update monthly summary

## Active PRs
- `perf-assist/limit-featured-programs-sql` — branch committed 2026-04-15 (commit f8eb334) but CANNOT be pushed (safeoutputs MCP unavailable x2, git creds blocked by AWF_ONE_SHOT_TOKENS); branch will be LOST when runner cleans up. MUST recreate from scratch next run. Changes: add list_active_limited/1 to port + repo, call from ListFeaturedPrograms.execute/0, 6 new tests.

## Completed Work
- PR #628 (parallelize Family.get_children + load_family_programs in parent DashboardLive) — confirmed merged 2026-04-14 ✓
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
