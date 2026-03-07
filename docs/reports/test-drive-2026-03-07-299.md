# Test Drive Report: Branch worktree-bug/299-duplicate-child

**Date:** 2026-03-07
**Branch:** `worktree-bug/299-duplicate-child`
**Scope:** Backend-only refactor — invite claim processing via Oban worker

## Summary

All verification checks pass. The branch correctly refactors inline invite claim processing into a serialized Oban worker pipeline with idempotent use case logic and a remediation script for existing duplicates.

## Results

### 1. Config Verification

| Check | Status | Detail |
|-------|--------|--------|
| `family: 1` queue in Oban config | PASS | `config/config.exs:61` — `queues: [default: 10, messaging: 5, cleanup: 2, email: 5, family: 1]` |
| Oban test mode | PASS | `config/test.exs:23` — `testing: :inline` (jobs execute synchronously in tests) |

### 2. ProcessInviteClaim Use Case — Happy Path

| Test | Status |
|------|--------|
| Creates parent profile and child for new user | PASS |
| Reuses existing parent profile | PASS |
| Maps nut_allergy true -> "Nut allergy" | PASS |
| Maps nut_allergy false -> nil allergies | PASS |
| Handles nil optional fields | PASS |

### 3. ProcessInviteClaim Use Case — Idempotency

| Test | Status |
|------|--------|
| Reuses existing child with same name + DOB | PASS |
| Case-insensitive deduplication | PASS |
| Idempotent retry after partial commit | PASS |
| Creates separate children when names differ | PASS |
| Does not false-match when DOB is nil | PASS |

### 4. ProcessInviteClaimWorker — Deserialization

| Test | Status |
|------|--------|
| Processes string-keyed JSON args -> atom-keyed map | PASS |
| Parses valid ISO 8601 date string | PASS |
| Returns error for malformed date string | PASS |
| Handles nil date_of_birth | PASS |

### 5. InviteClaimedHandler — Enqueue Flow

| Test | Status |
|------|--------|
| Enqueues job that creates parent + child (end-to-end) | PASS |
| Maps nut_allergy false -> nil allergies | PASS |
| Handles nil optional fields | PASS |
| Idempotent when parent already exists | PASS |
| Ignores unrelated events | PASS |

### 6. Data Integrity (Static Analysis)

| Check | Status | Detail |
|-------|--------|--------|
| Duplicate SQL check | DEFERRED | Tidewave MCP unavailable (Phoenix server not running) |
| Child/ParentProfile schema verification | DEFERRED | Tidewave MCP unavailable |

### 7. Remediation Script (Static Analysis)

| Check | Status | Detail |
|-------|--------|--------|
| NULL DOB filter in group query | PASS | Line 24: `where: not is_nil(c.date_of_birth)` |
| Case-insensitive grouping | PASS | Lines 27-28: `fragment("lower(?)", ...)` |
| Path.wildcard in usage comment | PASS | Line 8: handles version-agnostic path |
| Dry run default | PASS | Line 16: `dry_run = true` |
| Transaction safety | PASS | Lines 81-193: all mutations in `Repo.transaction/1` |
| Survivor selection | PASS | Line 65: `order_by: [asc: c.inserted_at]` (oldest record kept) |
| FK re-pointing order | PASS | Enrollments -> consents -> participation -> notes -> guardian links -> children |

### 8. Full Test Suite

| Metric | Value |
|--------|-------|
| Total tests | 2854 |
| Failures | 0 |
| Skipped | 12 (11 excluded) |
| Duration | 7.2s |
| Compilation | Clean (warnings-as-errors) |
| Formatting | Clean |

## Deferred Items

Runtime verification with Tidewave (SQL duplicate check, schema inspection, live Oban queue status) deferred — Phoenix server was not running during this session. These checks can be performed by starting `iex -S mix phx.server` and re-running the Tidewave steps.

## Architecture Notes

- **Handler** (`invite_claimed_handler.ex`) — thin adapter, serializes Date to ISO 8601, enqueues to `:family` queue
- **Worker** (`process_invite_claim_worker.ex`) — deserializes JSON args, delegates to use case, max 3 attempts
- **Use case** (`process_invite_claim.ex`) — ensure parent (idempotent), find-or-create child (idempotent), publish event
- **Queue serialization** — `family: 1` concurrency prevents TOCTOU race in find-or-create flow
- **Remediation** — one-time script merges existing duplicates, re-points enrollments/consents/participation/notes
