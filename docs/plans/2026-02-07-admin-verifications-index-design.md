# Admin Verifications Index Page — Design

## Goal

Wire the existing verification backend to the admin LiveView. Build the index page at `/admin/verifications` with status filtering.

## Context Layer

New function: `Identity.list_verification_documents_for_admin/1`

- Accepts optional status atom (`:pending`, `:approved`, `:rejected`, or `nil` for all)
- Delegates to new repo function `list_for_admin_review/1`
- Repo joins `verification_documents` with `providers` to get `business_name`
- Returns `{:ok, [%{document: VerificationDocument.t(), provider_business_name: String.t()}]}`
- Order: ascending by `inserted_at` for pending (FIFO), descending for others
- Domain model stays pure — enrichment at adapter/context boundary

Port change: `ForStoringVerificationDocuments` gets `list_for_admin_review/1` callback.

## LiveView Architecture

`VerificationsLive` — single module, no LiveComponents.

- **mount:** Page title only. No data loading.
- **handle_params:** Reads `?status=` query param, validates against allowed values, fetches via context, streams results with `reset: true`.
- **Assigns:** `:current_status` (atom or nil), `:document_count` (integer).

### Filter Tabs

Horizontal pill buttons: All | Pending | Approved | Rejected. Each is a `<.link patch={...}>` updating the query param. Active tab highlighted with `Theme.bg(:primary)`.

### Document List

Streamed with `dom_id: fn %{document: doc} -> "doc-#{doc.id}" end`.

Each item displays:
- Provider business name
- Document type (gettext-translated)
- Status badge (colored: yellow=pending, green=approved, red=rejected)
- Original filename
- Submitted date

Entire row is a `<.link navigate={~p"/admin/verifications/#{doc.id}"}>`.

### Empty State

Simple text message, varies by active filter (e.g., "No pending documents to review").

## Layout

Mobile-first. Cards on mobile, row layout on desktop (md+ breakpoint).

**Mobile card:** Provider name + badge (top), doc type (middle), filename + date (bottom).

**Desktop row:** Horizontal grid — provider, doc type, status, filename, date.

## File Changes

| File | Change |
|------|--------|
| `lib/klass_hero/identity.ex` | Add `list_verification_documents_for_admin/1` |
| `lib/klass_hero/identity/domain/ports/for_storing_verification_documents.ex` | Add `list_for_admin_review/1` callback |
| `lib/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository.ex` | Implement `list_for_admin_review/1` with provider join |
| `lib/klass_hero_web/live/admin/verifications_live.ex` | Full implementation replacing stub |

No new files. Domain model, mapper, router, auth hooks untouched.
