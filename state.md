# Perf Improver Memory — klass-hero

## Last Updated
2026-04-21

## Build / Test / Lint Commands (validated from mix.exs + CI)
- **Build**: `mix compile --warnings-as-errors`
- **Test**: `mix test` (CI: needs Postgres Docker via `docker-compose.yml`)
- **Format**: `mix format` / `mix format --check-formatted`
- **Pre-commit**: `mix precommit` (compile --warnings-as-errors, deps.unlock --unused, format, lint_typography, test)
- **Assets**: `mix assets.build` / `mix assets.deploy` (tailwind + esbuild)
- **Linting**: `mix credo --strict` (credo dep), `mix sobelow` (security)
- **Note**: Elixir/mix not available in CI runner environment — compile check not runnable
- **safeoutputs MCP**: `http://host.docker.internal:80/mcp/safeoutputs` with Authorization header from `/home/runner/.copilot/mcp-config.json`

## Run History
| Date | Tasks | Output |
|------|-------|--------|
| 2026-04-21 | T1, T2, T3, T7 | T1: mix/Elixir not in PATH confirmed. T2: Identified Admin.SessionsLive parallel opportunity. T3: Implemented parallelize Admin.SessionsLive.mount (providers+programs tasks), PR staged (branch perf-assist/parallelize-admin-sessions-mount). T7: Updated monthly summary #584 (PR #708 number resolved, new admin sessions PR added). |
| 2026-04-20 | T3, T4, T7 | T3: PR created for StaffParticipationLive parallelize (branch perf-assist/parallelize-staff-participation-mount, PR #708). T4: PRs #658 and #659 confirmed open, no CI issues. T7: Updated monthly summary #584. |
| 2026-04-19 | T3, T4, T6, T7 | T3: Implemented parallelize StaffParticipationLive.mount. T4: PRs #658, #659 confirmed open. T6: No new infra gaps. T7: monthly summary update blocked (safeoutputs unavailable). |
| 2026-04-16 | T4, T5, T7 | T4: Confirmed PR #659 and PR #658 open, PR #628 merged. T5: No new human comments on #478/#515. T7: Updated monthly summary #584. |
| 2026-04-12 | T1, T6, T5, T3, T7 | T3: PR #659 (SQL LIMIT) + PR #658 (parallelize StaffDashboardLive). T7: Updated April 2026 monthly summary. |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-04-21
- T2 (Identify opportunities): 2026-04-21
- T3 (Implement improvement): 2026-04-21
- T4 (Maintain PRs): 2026-04-20
- T5 (Comment on issues): 2026-04-16
- T6 (Measurement infra): 2026-04-19
- T7 (Activity summary): 2026-04-21

## Optimization Backlog (prioritized)
1. **[MERGED]** N+1 in DashboardLive — PR #290 ✓
2. **[MERGED]** Missing LiveView telemetry — PR #305 ✓
3. **[MERGED]** Parallelize ProgramDetailLive mount — PR #346 ✓
4. **[CLOSED/REJECTED]** Redundant DB query in ParticipationHistoryLive — PR #320 closed
5. **[MERGED]** Duplicate staff query in provider dashboard mount — PR #366 ✓
6. **[MERGED]** Redundant count_active_enrollments_batch — PR #382 ✓
7. **[MERGED]** Parallelize list_programs_for_provider + fetch_staff_members — PR #393 ✓
8. **[MERGED]** Duplicate get_parent_by_identity in DashboardLive.mount — PR #410 ✓
9. **[MERGED]** Duplicate get_parent_by_identity in BookingLive.mount — PR #419 ✓
10. **[CLOSED/REJECTED]** users.inserted_at index — PR #428 closed ("< 50 users, overkill")
11. **[MERGED]** Skip redundant conversations.get_by_id in SendMessage — PR #441 ✓
12. **[MERGED]** Pass conversation to SendMessage in MessagingLiveHelper hot path — PR #583 ✓
13. **[MERGED]** N+1 in StaffAssignmentHandler — PR #592 ✓
14. **[MERGED]** N+1 in CompleteSession.mark_remaining_as_absent — PR #602 ✓
15. **[MERGED]** Redundant providers table query in mount_conversation_show — PR #609 ✓
16. **[MERGED]** Parallelize SessionsLive.mount — PR #622 ✓
17. **[MERGED]** Parallelize parent DashboardLive.mount — PR #628 ✓
18. **[IN REVIEW]** Over-fetching in ListFeaturedPrograms.execute/0 — PR #659 (open)
19. **[IN REVIEW]** Parallelize Provider.get_provider_profile + list_programs_for_provider in StaffDashboardLive.mount — PR #658 (open)
20. **[IN REVIEW]** Parallelize list_programs_for_provider + get_session_with_roster_enriched in StaffParticipationLive.mount — PR #708 (open)
21. **[IN REVIEW]** Parallelize list_providers_for_select + list_programs_for_select in Admin.SessionsLive.mount — PR submitted 2026-04-21 (branch perf-assist/parallelize-admin-sessions-mount)
22. **[LOW]** StaffBroadcastLive.mount: Provider.get_provider_profile + ProgramCatalog.get_program_by_id are sequential but entitlements check depends on provider — not a simple parallelize
23. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries
24. **[LOW]** program_sessions.status index — verify query patterns first
25. **[PLANNED]** ETS projection cache for program→provider ACL resolution — issue #478, maintainer-designed

## Backlog Cursor
- Next tasks: T5 (comment on issues, last 2026-04-16), T4 (maintain PRs, last 2026-04-20), T6 (measurement infra, last 2026-04-19)
- Admin sessions PR number TBD (branch submitted 2026-04-21)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — includes LiveView metrics
- Maintainer is conservative about DB indexes for write-heavy tables AND small tables
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Maintainer is active and merges PRs quickly
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally
- Task.async/await parallel pattern is accepted by maintainer (multiple PRs merged)
- safeoutputs MCP: POST to http://host.docker.internal:80/mcp/safeoutputs with Authorization header; must send notifications/initialized after initialize before calling tools/call; session ID in Mcp-Session-Id header
- Index PRs pattern: only accepted when backed by production Honeycomb evidence AND non-trivial table size
- T6 infra state: no Benchee, no CI perf regression jobs; OTel + Honeycomb in prod; LiveDashboard in dev

## Active PRs
- PR #659: perf-assist/limit-featured-programs-query-c89d47071b72a9cb — open, awaiting review
- PR #658: perf-assist/parallelize-staff-dashboard-mount-99272bde2e3c3f24 — open, awaiting review
- PR #708: perf-assist/parallelize-staff-participation-mount — open, awaiting review
- PR (TBD): perf-assist/parallelize-admin-sessions-mount — submitted 2026-04-21, number TBD

## Completed Work
- PR #628 (parallelize Family.get_children + load_family_programs in parent DashboardLive) — merged 2026-04-12 ✓
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
