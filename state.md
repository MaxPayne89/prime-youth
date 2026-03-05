# Perf Improver Memory — prime-youth

## Last Updated
2026-03-05

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
| 2026-03-05 | T1, T2, T3, T7 | First run. PR created for missing DB indexes. |

## Task Last Run (Round-Robin)
- T1 (Discover commands): 2026-03-05
- T2 (Identify opportunities): 2026-03-05
- T3 (Implement improvement): 2026-03-05
- T4 (Maintain PRs): never
- T5 (Comment on issues): never
- T6 (Measurement infra): never
- T7 (Activity summary): 2026-03-05

## Optimization Backlog (prioritized)
1. **[HIGH] Missing DB indexes** — `program_sessions.session_date` and `participation_records.provider_id`. Both FK/filter columns with no index; sequential scans as data grows. PR submitted: `perf-assist/add-missing-db-indexes`. **Status: PR created.**
2. **[MED] Two-step query in `with_ended_program/2`** — Messaging context fetches ended program IDs to Elixir then passes as `IN` list. Could grow large. Subquery would be 1 DB round-trip. Note: changing this would require importing ProgramSchema into Messaging, violating bounded-context architecture. Needs discussion before changing.
3. **[MED] Conversation list performance** — `order_by_recent_message` does a LEFT JOIN + MAX aggregation on messages. As conversations grow, this could be slow. A `last_message_at` denormalized column on conversations could help, but requires application-level maintenance.
4. **[LOW] program_sessions.status index** — No index on status column; if filtering by status is common, this could help.
5. **[LOW] program_listings missing date indexes** — No index on `start_date` or `end_date` in `program_listings`. If filtering by date range is common, this would help.

## Backlog Cursor
- Last opportunity scan ended at: program_listings (migration 12 of 14)
- Next: Check T4 (maintain PRs) and T5 (comment on issues) in next run

## Performance Notes
- Phoenix app with OpenTelemetry configured (could use trace data for real-world perf)
- Oban for background jobs (already indexed via its own migration)
- Cursor-based pagination on programs (good: avoids OFFSET)
- Messaging has `total_unread_count` query that joins 3 tables - monitor as scale grows

## Active PRs
- `perf-assist/add-missing-db-indexes` — submitted 2026-03-05, not yet merged

## Completed Work
(none yet)

## Previously Checked Off Suggested Actions
(none yet)
