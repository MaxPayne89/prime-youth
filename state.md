# Perf Improver Memory — prime-youth

## Last Updated
2026-03-07

## Build / Test / Lint Commands (validated from mix.exs + CI)
- **Build**: `mix compile --warnings-as-errors`
- **Test**: `mix test` (CI: needs Postgres Docker via `docker-compose.yml`)
- **Format**: `mix format` / `mix format --check-formatted`
- **Pre-commit**: `mix precommit` (compile --warnings-as-errors, deps.unlock --unused, format, test)
- **Assets**: `mix assets.build` / `mix assets.deploy` (tailwind + esbuild)
- **Linting**: `mix credo --strict` (credo dep), `mix sobelow` (security)

## Run History
| Date | Tasks | Output |
|------|-------|--------|
| 2026-03-07 | T4, T5, T6, T7 | T4: PR #290 CI pending/no comments — no action. T5: No open perf issues. T6: Added LiveView telemetry metrics PR (perf-assist/liveview-telemetry-metrics). T7: Monthly summary updated. |
| 2026-03-06 | T3, T4(n/a), T5(n/a), T7 | T3: PR created for DashboardLive N+1 batch program loading (#290). T4: PR #283 was closed by maintainer (rejected). T5: No open performance issues to comment on. |
| 2026-03-05 | T1, T2, T3, T7 | First run. PR #283 created for missing DB indexes (later closed/rejected by maintainer). |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-03-05
- T2 (Identify opportunities): 2026-03-05
- T3 (Implement improvement): 2026-03-06
- T4 (Maintain PRs): 2026-03-07
- T5 (Comment on issues): 2026-03-07 (no perf issues open)
- T6 (Measurement infra): 2026-03-07
- T7 (Activity summary): 2026-03-07

## Optimization Backlog (prioritized)
1. **[IN REVIEW] N+1 in DashboardLive** — PR #290: `get_programs_by_ids/1` batch function (was flagged in code as a "Future optimization"). CI pending.
2. **[IN REVIEW] Missing LiveView telemetry** — PR submitted 2026-03-07 (perf-assist/liveview-telemetry-metrics): adds mount/handle_params/handle_event/render metrics to LiveDashboard.
3. **[REJECTED] Missing DB indexes** — PR #283 closed. Do NOT re-propose.
4. **[MED] Two-step query in `with_ended_program/2`** — Messaging context fetches ended program IDs to Elixir then passes as `IN` list. Architecture constraint: subquery crosses DDD boundaries.
5. **[MED] Conversation list performance** — `order_by_recent_message` does a LEFT JOIN + MAX aggregation on messages. Denormalized `last_message_at` could help at scale.
6. **[LOW] program_sessions.status index** — Maintainer conservative on indexes — verify query patterns first.
7. **[LOW] program_listings date indexes** — Same caveat.

## Backlog Cursor
- Next: T1 (revalidate commands) or T2 (new opportunity scan) in next run

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing
- LiveDashboard at `/dev/dashboard` uses `KlassHeroWeb.Telemetry` — now includes LiveView metrics
- Maintainer is conservative about DB indexes: "not justified based on the current query patterns" (from PR #283)
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- `get_by_ids` pattern added to ProgramCatalog; similar batch patterns may be needed elsewhere
- `live_debugger` and `phoenix_live_dashboard` both installed in deps

## Active PRs
- `perf-assist/batch-program-loading-3a52eb84ff654398` (#290) — submitted 2026-03-06 (N+1 fix in DashboardLive), CI pending
- `perf-assist/liveview-telemetry-metrics` — submitted 2026-03-07 (LiveView telemetry metrics)

## Completed Work
- PR #283 (DB indexes) — submitted 2026-03-05, closed/rejected 2026-03-05 by maintainer (not justified)

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
