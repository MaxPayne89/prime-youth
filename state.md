# Perf Improver Memory — prime-youth

## Last Updated
2026-03-09

## Build / Test / Lint Commands (validated from mix.exs + CI)
- **Build**: `mix compile --warnings-as-errors`
- **Test**: `mix test` (CI: needs Postgres Docker via `docker-compose.yml`)
- **Format**: `mix format` / `mix format --check-formatted`
- **Pre-commit**: `mix precommit` (compile --warnings-as-errors, deps.unlock --unused, format, test)
- **Assets**: `mix assets.build` / `mix assets.deploy` (tailwind + esbuild)
- **Linting**: `mix credo --strict` (credo dep), `mix sobelow` (security)
- **Note**: Elixir/mix not available in CI runner environment — compile check not runnable

## Run History
| Date | Tasks | Output |
|------|-------|--------|
| 2026-03-09 | T4, T3, T7 | T4: PR #320 (redundant child query) was closed without merge by maintainer (no comment). T3: Created PR perf-assist/parallel-program-detail-mount — parallelizes load_team_members + get_participant_policy in ProgramDetailLive mount with Task.async. T7: Monthly summary updated. |
| 2026-03-08 | T2, T3, T7 | T2: Both previous PRs (#290, #305) confirmed merged by maintainer — updated backlog accordingly. T2: Identified redundant `Family.get_child_ids_for_parent/1` call in `ParticipationHistoryLive.apply_history/4` — extra DB query when `children` already in scope. T3: Created PR `perf-assist/eliminate-redundant-child-query` — replaces redundant DB call with `MapSet.new(children, &1.id)`; saves 1 DB round-trip per participation history page load. |
| 2026-03-07 | T4, T5, T6, T7 | T4: PR #290 CI pending/no comments — no action. T5: No open perf issues. T6: Added LiveView telemetry metrics PR (#305). T7: Monthly summary updated. |
| 2026-03-06 | T3, T4, T5, T7 | T3: PR #290 created for DashboardLive N+1 batch program loading. T4: PR #283 was closed by maintainer (rejected). T5: No open performance issues. |
| 2026-03-05 | T1, T2, T3, T7 | First run. PR #283 created for missing DB indexes (later closed/rejected by maintainer). |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-03-05
- T2 (Identify opportunities): 2026-03-08
- T3 (Implement improvement): 2026-03-09
- T4 (Maintain PRs): 2026-03-09
- T5 (Comment on issues): 2026-03-07 (no perf issues open)
- T6 (Measurement infra): 2026-03-07
- T7 (Activity summary): 2026-03-09

## Optimization Backlog (prioritized)
1. **[MERGED]** N+1 in DashboardLive — PR #290 merged 2026-03-07.
2. **[MERGED]** Missing LiveView telemetry — PR #305 merged 2026-03-07.
3. **[CLOSED/REJECTED]** Redundant DB query in ParticipationHistoryLive — PR #320 closed without merge 2026-03-09 (no maintainer comment — may have been superseded by worktree-refactor/300-duplicate-code or similar refactor).
4. **[IN REVIEW]** Parallelize ProgramDetailLive mount — PR created 2026-03-09: `load_team_members` + `get_participant_policy` run concurrently with Task.async/await.
5. **[MED]** Two-step query in `with_ended_program/2` — Messaging context fetches ended program IDs to Elixir then passes as `IN` list. Architecture constraint: subquery crosses DDD boundaries.
6. **[LOW]** program_sessions.status index — Maintainer conservative on indexes — verify query patterns first.
7. **[LOW]** program_listings date indexes — Same caveat.

## Backlog Cursor
- Next run: T1 (revalidate commands) + T5 (perf issue comments) or T6 (measurement infra)

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — now includes LiveView metrics (merged PR #305)
- Maintainer is conservative about DB indexes: "not justified based on the current query patterns" (from PR #283)
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- `get_by_ids` pattern now in ProgramCatalog (from PR #290)
- `live_debugger` and `phoenix_live_dashboard` both installed in deps
- Maintainer is active and merges PRs quickly (both #290 and #305 merged same day)
- `filter_programs` is intentionally in-memory (word-boundary matching; DB-level impractical without FTS)
- `conversation_summaries` table already denormalizes `unread_count` and `latest_message_at` — backlog item (conversation list) is already addressed at the data layer
- Elixir/mix is not in PATH in the CI runner environment — cannot run `mix compile` or `mix test` locally

## Active PRs
- `perf-assist/parallel-program-detail-mount` — created 2026-03-09 (Task.async parallelization of ProgramDetailLive mount DB queries)

## Completed Work
- PR #290 (N+1 in DashboardLive) — merged 2026-03-07 by maintainer
- PR #305 (LiveView telemetry metrics) — merged 2026-03-07 by maintainer
- PR #283 (DB indexes) — closed/rejected 2026-03-05 by maintainer (not justified)
- PR #320 (redundant child query) — closed without merge 2026-03-09 (no comment)

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
