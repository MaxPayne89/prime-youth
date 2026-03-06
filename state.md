# Perf Improver Memory — prime-youth

## Last Updated
2026-03-06

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
| 2026-03-06 | T3, T4(n/a), T5(n/a), T7 | T3: PR created for DashboardLive N+1 batch program loading. T4: PR #283 was closed by maintainer (rejected). T5: No open performance issues to comment on. |
| 2026-03-05 | T1, T2, T3, T7 | First run. PR #283 created for missing DB indexes (later closed/rejected by maintainer). |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-03-05
- T2 (Identify opportunities): 2026-03-05
- T3 (Implement improvement): 2026-03-06
- T4 (Maintain PRs): 2026-03-06 (no open PRs)
- T5 (Comment on issues): 2026-03-06 (no perf issues open)
- T6 (Measurement infra): never
- T7 (Activity summary): 2026-03-06

## Optimization Backlog (prioritized)
1. **[DONE] N+1 in DashboardLive** — PR submitted 2026-03-06: replaced N+1 program lookups with batch `get_programs_by_ids/1`. Code itself flagged this as a "Future optimization".
2. **[REJECTED] Missing DB indexes** — `program_sessions.session_date` and `participation_records.provider_id`. PR #283 was closed by maintainer: "not justified based on the current query patterns". Do NOT re-propose.
3. **[MED] Two-step query in `with_ended_program/2`** — Messaging context fetches ended program IDs to Elixir then passes as `IN` list. Architecture constraint: subquery would require importing ProgramSchema into Messaging context (violates DDD boundaries). Needs discussion.
4. **[MED] Conversation list performance** — `order_by_recent_message` does a LEFT JOIN + MAX aggregation on messages. Denormalized `last_message_at` could help at scale.
5. **[LOW] program_sessions.status index** — No index on status column; if filtering by status is common, this could help. Maintainer may reject as "not justified" like previous indexes.
6. **[LOW] program_listings missing date indexes** — No index on `start_date`/`end_date`. Same caveat.

## Backlog Cursor
- Next: T6 (Measurement infra assessment — never run) in next run

## Performance Notes
- Phoenix app with OpenTelemetry + Honeycomb configured for production tracing — good production monitoring
- Maintainer is conservative about DB indexes: "not justified based on the current query patterns" (from PR #283 comment)
- No benchmark suite (Benchee or similar) — new dep would need discussion first
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- Messaging has `total_unread_count` query that joins 3 tables - monitor as scale grows
- `get_by_ids` pattern added to ProgramCatalog; similar batch patterns may be needed elsewhere

## Active PRs
- `perf-assist/batch-program-loading` — submitted 2026-03-06 (N+1 fix in DashboardLive)

## Completed Work
- PR #283 (DB indexes) — submitted 2026-03-05, closed/rejected 2026-03-05 by maintainer (not justified)

## Previously Checked Off Suggested Actions
- "Review PR" for DB indexes (from 2026-03 monthly summary) — checked off by maintainer
