# Auto-Verify Provider on Document Approval

**Issue:** #244 — Business Verification Pending Review
**Date:** 2026-03-02

## Problem

Approving verification documents does not update the provider's `verified` status.
`ApproveVerificationDocument` sets `verification_documents.status = "approved"` but
`providers.verified` stays `false`. Two independent verification systems with no automation.

## Decision

Use domain events within the Provider bounded context to bridge document approval
and provider verification. Follows the established DomainEventBus pattern used by
Accounts, Family, Enrollment, and ProgramCatalog.

## Design

### Event Flow

```
ApproveVerificationDocument.execute/2
  ├── Persist approved doc
  └── Dispatch :verification_document_approved domain event
        └── Handler: CheckProviderVerificationStatus
              ├── All docs approved? → VerifyProvider.execute
              └── Otherwise → no-op

RejectVerificationDocument.execute/3
  ├── Persist rejected doc
  └── Dispatch :verification_document_rejected domain event
        └── Handler: CheckProviderVerificationStatus
              ├── Provider verified? → UnverifyProvider.execute
              └── Otherwise → no-op
```

### Key Invariant

`providers.verified = true` ↔ all provider's verification documents are approved.

### Event Scope

Domain events only (internal to Provider context). No integration event promotion for
doc-level events. `VerifyProvider` and `UnverifyProvider` already publish integration
events (`:provider_verified` / `:provider_unverified`) for cross-context consumers.

### Error Handling

- Handler uses fire-and-forget dispatch — failures logged but don't fail doc approval
- `VerifyProvider`/`UnverifyProvider` are idempotent

## Files

### New

- `lib/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status.ex`

### Modified

- `lib/klass_hero/provider/application/use_cases/verification/approve_verification_document.ex` — dispatch domain event
- `lib/klass_hero/provider/application/use_cases/verification/reject_verification_document.ex` — dispatch domain event
- `lib/klass_hero/application.ex` — register handlers on Provider DomainEventBus

### Tests

- Unit: handler logic (all approved → verify, rejection → unverify, partial → no-op)
- Use case: verify domain events are dispatched
- Integration: full flow from doc approval to provider verification
