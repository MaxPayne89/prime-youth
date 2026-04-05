# Perf Improver Memory — klass-hero

## Last Updated
2026-04-05

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
| 2026-04-05 | T5, T2, T4, T7 | T4: PR #592 CI clean. T2: Identified N+1 in CompleteSession.mark_remaining_as_absent (list_by_session + N×Repo.get+Repo.update). T5: Commented on #515 with PubSub fan-out measurement guidance. T7: Updated April 2026 monthly summary. |
| 2026-04-04 | T4, T2, T3, T7 | T4: PR #583 confirmed merged. T2: Confirmed N+1 in StaffAssignmentHandler — N inserts per staff assignment event. T3: Created PR #592 perf-assist/batch-staff-participant-inserts — new add_to_conversations_batch/2 port callback + insert_all impl; reduces N+1 to 2 queries per staff assignment. T7: Updated April 2026 monthly summary. |
| 2026-04-03 | T1, T2, T6, T3, T7 | T1: Commands unchanged. T6: Maintainer already enabled Elixir 1.20 interpreted compilation + parallel dep builds (PR merged 2026-04-01). T2: Found MessagingLiveHelper.handle_send_message doesn't pass conversation to SendMessage — redundant DB fetch on every message send. T3: Created PR perf-assist/pass-conversation-to-send-message-in-live-helper — merged same day as PR #583. T7: Closed March 2026 (#284), created April 2026 monthly summary. |
| 2026-03-16 | T5, T3, T7 | T5: Commented on #431. T3: Created PR perf-assist/skip-conversation-fetch-in-send-message — merged 2026-03-16 as PR #441. |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-04-03
- T2 (Identify opportunities): 2026-04-05
- T3 (Implement improvement): 2026-04-04
- T4 (Maintain PRs): 2026-04-05
- T5 (Comment on issues): 2026-04-05
- T6 (Measurement infra): 2026-04-03
- T7 (Activity summary): 2026-04-05

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
13. **[IN REVIEW]** N+1 in StaffAssignmentHandler.add_staff_to_existing_conversations — PR #592 submitted 2026-04-04; new add_to_conversations_batch/2 + insert_all
14. **[MEDIUM]** N+1 in CompleteSession.mark_remaining_as_absent — list_by_session (1 query) then N×(Repo.get + Repo.update) for absent children; mark_absent_batch via Repo.update_all would reduce to 2 queries; trade-off: per-record domain events still needed
15. **[LOW]** Two-step query in `with_ended_program/2` — background job only; crosses DDD boundaries
16. **[LOW]** program_sessions.status index — verify query patterns first

## Backlog Cursor
- Next run: T3 (implement CompleteSession N+1 fix), T1 (revalidate commands), T6 (measurement infra)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — includes LiveView metrics
- Maintainer is conservative about DB indexes for write-heavy tables AND small tables
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Maintainer is active and merges PRs quickly
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally
- Maintainer shipped test suite speed-up (PR #588): 60s → 28s (disable Req retries in test + replace collect_spans pattern with assert_span macro)
- SendMessage.execute accepts optional :conversation opt — when provided, skips the conversations.get_by_id fetch
- Index PRs pattern: only accepted when backed by production Honeycomb evidence AND non-trivial table size
- add_batch/2 on ParticipantRepository handles (one conversation, many users) via insert_all
- add_to_conversations_batch/2 (new, PR #592) handles (one user, many conversations) via insert_all
- ParticipationRepository.update/1 always does Repo.get before Repo.update (for changeset generation); creates hidden N+1 in callers that already hold loaded records
- PubSubIntegrationEventPublisher uses Phoenix.PubSub.broadcast!/3; PubSub partition count is a tuning lever for fan-out under load

## Active PRs
- `perf-assist/batch-staff-participant-inserts` (#592) — created 2026-04-04; new add_to_conversations_batch/2 + insert_all impl; reduces N+1 to 2 queries per staff assignment event

## Completed Work
- PR #583 (pass conversation to MessagingLiveHelper SendMessage) — merged 2026-04-03 ✓
- PR #441 (skip conversation fetch in SendMessage for ReplyPrivatelyToBroadcast) — merged 2026-03-16 ✓
- PR #419 (eliminate duplicate parent lookup in BookingLive.mount) — merged 2026-03-15 ✓
- PR #428 (users.inserted_at index) — closed 2026-03-15 ("< 50 users, overkill")
- PR #410 (eliminate duplicate parent lookup in DashboardLive.mount) — merged 2026-03-14 ✓

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
