# Architecture Review: Auto-Verify Provider on Document Approval

**Branch:** `worktree-bug/244-admin-verification-review`
**Issue:** #244 — Business Verification Pending Review
**Date:** 2026-03-02 (post-merge from main)

## Summary

Domain-event-driven auto-verification/unverification of providers when documents approved/rejected. 9 files changed (core feature only — mapper refactoring and CSS changes were on main).

## Verdicts

| Area | Result |
|------|--------|
| Bounded Context Boundaries | PASS |
| Ports & Adapters Layering | PASS |
| Dependency Direction | PASS |
| Domain Model Integrity | PASS |
| Event Classification | PASS |
| Naming & Structure | PASS |
| Anti-Patterns | PASS — none detected |

## Important Issues

### 1. Event dispatch outside transaction boundary

`approve_verification_document.ex:43`, `reject_verification_document.ex:49`

`dispatch_event/2` fires after the `with` chain. If `VerifyProvider.execute` (triggered by handler) fails, document is approved but provider not verified. `Logger.warning` in handler catches this, but no retry mechanism.

**Risk:** Low — invariant can be manually corrected. Consider periodic reconciliation long-term.

## Suggestions

1. **Test helper duplication** — `create_pending_document/1` duplicated in handler test and integration test. Extract to shared helper if more tests added.

## Strengths

1. Clean layered event architecture: doc domain events → handler → provider use cases → integration events
2. Follows established patterns from Accounts, Enrollment, Messaging contexts
3. Comprehensive test coverage (unit, event dispatch, full integration)
4. Design docs in `docs/plans/` with decision rationale
5. Idempotent use cases prevent duplicate event issues
