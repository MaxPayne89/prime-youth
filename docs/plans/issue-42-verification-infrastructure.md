# Issue #42 — Business Plan: Overview & Verification Infrastructure

## Infrastructure (doesn't exist yet)
- [ ] Provision Tigris buckets on Fly (2 per env — public + private)
- [ ] Add S3-compatible upload deps (`ex_aws`, `ex_aws_s3`, `sweet_xml`)
- [ ] Add MinIO to Docker test setup
- [ ] Configure Tigris credentials (env vars in runtime.exs)
- [ ] Build a file upload module (upload to Tigris, get back a URL; signed URLs for private bucket)

## Database
- [ ] Create `verification_documents` table (provider_id, document_type, file_url, status, etc.)
- [ ] Migration for the new table

## Domain layer (Identity context)
- [ ] Add `update_provider_profile` capability (port, repository, use case, facade) — currently only `create` exists
- [ ] Add VerificationDocument domain model, port, repository, mapper (full DDD stack)
- [ ] Add document submission + review use cases

## Web layer
- [ ] Provider settings page (`/provider/settings`) — edit business info, upload logo, upload verification docs
- [ ] Wire LiveView uploads to Tigris via the upload module
- [ ] Admin verification page (`/admin/verifications`) — list pending docs, approve/reject
- [ ] Add admin role check (`:admin` role + `require_admin` mount hook)
- [ ] Overview tab — show real verification status instead of mock data
- [ ] "New Program" button — disable when provider not verified (UI + backend guard)

---

## Detail: Storage Architecture (Tigris)

### Bucket Strategy — Two buckets per environment

| Environment | Storage Backend | Public Bucket | Private Bucket |
|---|---|---|---|
| Test | MinIO (Docker) | `test-public` | `test-private` |
| Dev | Tigris | `klass-hero-dev-public` | `klass-hero-dev-private` |
| Prod | Tigris | `klass-hero-prod-public` | `klass-hero-prod-private` |

**Public bucket** — serves files directly via URL. No auth needed to fetch.
Used for anything that anonymous visitors need to see (program images, logos, profile pics).

**Private bucket** — requires signed URLs with expiration.
App generates a short-lived link only after verifying the requesting user is the owner or an admin.
Used for sensitive documents (verification docs, insurance PDFs, etc.).

### Key Prefix Structure (virtual folders)

```
klass-hero-{env}-public/
  logos/providers/{provider_id}/{filename}
  program-images/programs/{program_id}/{filename}
  profile-pics/users/{user_id}/{filename}

klass-hero-{env}-private/
  verification-docs/providers/{provider_id}/{filename}
```

New content types (e.g. program videos) slot in as additional prefixes — no restructuring needed.

### Access Patterns

| Content | Bucket | Served via | Who can access |
|---|---|---|---|
| Provider logos | public | Direct URL | Anyone |
| Program images | public | Direct URL | Anyone |
| Profile pictures | public | Direct URL | Anyone |
| Verification docs | private | Signed URL (expiring) | Owning provider + admins |

### Upload Module Design

Single `KlassHero.Storage` module with a behaviour-backed adapter:
- **Prod/Dev adapter:** `ExAws.S3` pointing at Tigris
- **Test adapter:** `ExAws.S3` pointing at MinIO (same API, local Docker container)

The module exposes:
- `upload(bucket_type, path, binary)` → `{:ok, url}` — upload file, return public URL or storage key
- `signed_url(key, expires_in)` → `{:ok, signed_url}` — generate expiring URL for private files
- `delete(bucket_type, key)` → `:ok` — remove a file

`bucket_type` is `:public` or `:private` — the module resolves to the correct bucket name based on environment config.

### Image Processing (deferred)

Not in scope for issue #42. When needed:
- Resize/compress on upload (cap at e.g. 1200px wide)
- Potentially generate thumbnail variants
- Will be handled in the upload module without changing the bucket structure
