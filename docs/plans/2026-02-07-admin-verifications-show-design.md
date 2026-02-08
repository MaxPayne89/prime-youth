# Admin Verification Detail Page Design

## Overview

Build the `:show` action for `VerificationsLive` — display document details, inline preview via signed URL, and approve/reject workflow.

## Page Layout (top to bottom)

1. **Back link** — `< Back to verifications` → `/admin/verifications`
2. **Header** — Document type as title + status badge (reuse existing component)
3. **Info grid** — 2-col desktop, stacked mobile: business name, original filename, submitted date, reviewed date (if reviewed)
4. **Document preview** — Inline image/iframe based on file extension, with download link
5. **Action section** — Approve/Reject buttons (pending only)
6. **Rejection form** — Hidden by default, toggled on Reject click. Textarea + Confirm Rejection button

## Data Loading

- Fetch document via new `Identity.get_verification_document_for_admin(id)` which joins provider business name
- Returns `{:ok, %{document: doc, provider_business_name: name}}` or `{:error, :not_found}`
- Not found → redirect to index with error flash
- Generate signed URL via `Storage.signed_url(:private, document.file_url, 900)` (15 min expiry)

## Document Preview

Determine type from original filename extension:
- **Images** (jpg, jpeg, png, gif, webp) — `<img>` tag, max-width constrained, clickable for full-size in new tab
- **PDFs** (pdf) — `<iframe>` with ~600px height
- **Other** — "Preview not available" with file icon

All types get a "Download document" link (signed URL, new tab). If signed URL fails, show download link only with error note.

## Approve Flow

1. Click "Approve"
2. `handle_event("approve")` → `Identity.approve_verification_document(doc.id, user.id)`
3. Success: re-fetch document, update assigns, flash "Document approved successfully"
4. Error: flash error message
5. Action buttons disappear (no longer pending)

## Reject Flow

1. Click "Reject" → toggles `show_reject_form` assign
2. Textarea appears with Cancel link (resets form visibility)
3. Submit → `handle_event("reject", %{"rejection" => %{"reason" => reason}})`
4. Calls `Identity.reject_verification_document(doc.id, user.id, reason)`
5. Success: re-fetch, hide form, flash "Document rejected"
6. Error: flash error. Client-side `required` attribute on textarea

## Post-Review Display

- Status badge updates to approved/rejected
- Rejected: show rejection reason in highlighted block
- Show reviewed-by and reviewed-at info
- No action buttons

## Context API Addition

New function: `Identity.get_verification_document_for_admin/1`

Requires:
- New `get_for_admin_review/1` callback on `ForStoringVerificationDocuments` port
- Implementation in `VerificationDocumentRepository` — join provider_profiles, select business_name + document

## Assigns

- `document` — VerificationDocument domain model
- `provider_business_name` — string
- `signed_url` — presigned URL string (or nil on failure)
- `show_reject_form` — boolean, default false
- `reject_form` — form for rejection textarea

## No Changes Needed

- Domain model (VerificationDocument) — already has approve/reject
- Use cases (approve/reject) — already implemented
- Storage system — signed_url already available
- Router — route already defined
