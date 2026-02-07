# Verification Infrastructure Design

Issue: #42

## Overview

This design covers object storage infrastructure, provider verification documents, admin review workflows, and program creation guards for unverified providers.

---

## 1. Storage Infrastructure (Shared Context)

### Port Definition

`lib/klass_hero/shared/domain/ports/for_storing_files.ex`

Behaviour with three callbacks:
- `upload(bucket_type, path, binary, opts)` → `{:ok, url} | {:error, reason}`
- `signed_url(bucket_type, key, expires_in_seconds)` → `{:ok, url} | {:error, reason}`
- `delete(bucket_type, key)` → `:ok | {:error, reason}`

`bucket_type` is `:public | :private`. Adapter resolves to actual bucket names from config.

### Adapters

1. **S3StorageAdapter** — production/dev using `ex_aws` + `ex_aws_s3`. Reads bucket names and credentials from runtime config.
2. **StubStorageAdapter** — test adapter. Stores uploads in Agent, returns canned URLs. Default in test env.

### Dependencies

Add to `mix.exs`:
```elixir
{:ex_aws, "~> 2.5"}
{:ex_aws_s3, "~> 2.5"}
{:sweet_xml, "~> 0.7"}
```

### Config Structure

```elixir
# config/runtime.exs
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.S3StorageAdapter,
  public_bucket: System.get_env("STORAGE_PUBLIC_BUCKET"),
  private_bucket: System.get_env("STORAGE_PRIVATE_BUCKET"),
  endpoint: System.get_env("STORAGE_ENDPOINT"),  # nil for real S3/Tigris, set for MinIO
  access_key_id: System.get_env("STORAGE_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("STORAGE_SECRET_ACCESS_KEY")
```

### Bucket Strategy

| Environment | Backend | Public Bucket | Private Bucket |
|---|---|---|---|
| Test | MinIO | `test-public` | `test-private` |
| Dev | Tigris | `klass-hero-dev-public` | `klass-hero-dev-private` |
| Prod | Tigris | `klass-hero-prod-public` | `klass-hero-prod-private` |

### Key Prefix Structure

```
{bucket}-public/
  logos/providers/{provider_id}/{filename}
  program-images/programs/{program_id}/{filename}
  profile-pics/users/{user_id}/{filename}

{bucket}-private/
  verification-docs/providers/{provider_id}/{filename}
```

---

## 2. Docker & Test Setup

### docker-compose.yml Additions

```yaml
minio:
  image: minio/minio:latest
  command: server /data --console-address ":9001"
  ports:
    - "9000:9000"
    - "9001:9001"
  environment:
    MINIO_ROOT_USER: minioadmin
    MINIO_ROOT_PASSWORD: minioadmin
  volumes:
    - minio_data:/data
```

### Test Environment Config

```elixir
# config/test.exs
config :klass_hero, :storage,
  adapter: KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter
```

Integration tests tagged `@tag :integration` override to S3 adapter pointing at MinIO.

### StubStorageAdapter

- `upload/4` — stores in Agent, returns `{:ok, "stub://#{bucket_type}/#{path}"}`
- `signed_url/3` — returns `{:ok, "stub://signed/#{key}?expires=#{expires_in}"}`
- `delete/2` — removes from Agent, returns `:ok`
- `get_uploaded/2` — test helper for assertions

### mix test.setup Extensions

1. Start MinIO container alongside Postgres
2. Create test buckets (`test-public`, `test-private`)

---

## 3. Verification Documents (Identity Context)

### Database Schema

New table `verification_documents`:

| Column | Type | Notes |
|---|---|---|
| id | binary_id | PK |
| provider_profile_id | FK | → provider_profiles |
| document_type | string | e.g., "business_registration", "insurance_certificate" |
| file_url | string | storage key for private bucket |
| original_filename | string | user's uploaded filename |
| status | string | "pending", "approved", "rejected" |
| rejection_reason | string | nullable |
| reviewed_by_id | FK | → users, nullable |
| reviewed_at | utc_datetime_usec | nullable |
| inserted_at | utc_datetime_usec | |
| updated_at | utc_datetime_usec | |

### Domain Model

`lib/klass_hero/identity/domain/models/verification_document.ex` — pure struct with validation. Status constrained to known values.

### Port & Adapter

- Port: `ForStoringVerificationDocuments` — `create/1`, `get/1`, `get_by_provider/1`, `update/2`
- Repository: `VerificationDocumentRepository`
- Schema: `VerificationDocumentSchema`
- Mapper: `VerificationDocumentMapper`

### Use Cases

1. **SubmitVerificationDocument** — provider uploads doc. Calls storage port (private bucket), creates record with status "pending".
2. **ApproveVerificationDocument** — admin approves. Sets status "approved", records reviewer + timestamp.
3. **RejectVerificationDocument** — admin rejects with reason. Sets status "rejected", records rejection_reason + reviewer + timestamp.

### Document Lifecycle

Simple two-state: `pending` → `approved` or `rejected`. Rejected docs get a reason. Provider uploads new doc as new record (no resubmission on same record).

---

## 4. Provider Profile Updates (Identity Context)

### New Use Cases

1. **UpdateProviderProfile** — updates business info (name, description, phone, website, address). Does not touch verification.
2. **UploadProviderLogo** — calls storage port (public bucket at `logos/providers/{id}/{filename}`), updates `logo_url`.
3. **VerifyProvider** — admin action. Sets `verified: true`, `verified_at: now()`. Publishes integration event.
4. **UnverifyProvider** — admin action. Sets `verified: false`, clears `verified_at`. Publishes integration event.
5. **ChangeProviderProfile** — returns changeset for LiveView form binding.

### Repository Extensions

Add to `ForStoringProviderProfiles` port:
- `update/2`
- `get/1` (by profile ID)
- `list_unverified/0`
- `list_all/1` (paginated with filters)
- `list_verified_ids/0` (for bootstrap query)

### Facade Additions

- `update_provider_profile/2`
- `upload_provider_logo/2`
- `verify_provider/2`
- `unverify_provider/2`
- `change_provider_profile/2`
- `list_verified_provider_ids/0`

### Integration Events

Published after verify/unverify:
- `integration:identity:provider_verified` — `%{provider_id: id}`
- `integration:identity:provider_unverified` — `%{provider_id: id}`

---

## 5. Admin Infrastructure

### User Schema Addition

Add to `accounts/user.ex`:
- `is_admin` (boolean, default: false)

Set via seed/migration, never UI-exposed.

### Admin Mount Hook

`lib/klass_hero_web/user_auth.ex`:

```elixir
def on_mount(:require_admin, _params, _session, socket) do
  if socket.assigns.current_scope.user.is_admin do
    {:cont, socket}
  else
    {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
  end
end
```

### Router

```elixir
live_session :require_admin,
  on_mount: [
    {KlassHeroWeb.UserAuth, :mount_current_scope},
    {KlassHeroWeb.UserAuth, :require_authenticated},
    {KlassHeroWeb.UserAuth, :require_admin}
  ] do
  scope "/admin", KlassHeroWeb.Admin do
    pipe_through :browser

    live "/verifications", VerificationsLive, :index
    live "/verifications/:id", VerificationsLive, :show
  end
end
```

---

## 6. Web Layer — Provider Settings

### LiveView

`lib/klass_hero_web/live/provider/settings_live.ex` at `/provider/settings`

### Sections

1. **Business Info** — form for business_name, description, phone, website, address
2. **Logo** — image upload with preview
3. **Verification Documents** — list with status badges, upload form with document_type dropdown

### Upload Config

```elixir
allow_upload(:logo, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 5_000_000)
allow_upload(:verification_doc, accept: ~w(.pdf .jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000)
```

### Access Control

Lives in `:require_provider` live_session.

---

## 7. Web Layer — Admin Verifications

### LiveView

`lib/klass_hero_web/live/admin/verifications_live.ex`

### Index (`/admin/verifications`)

- List pending verification documents
- Filter tabs: All / Pending / Approved / Rejected
- Shows provider name, document type, uploaded date
- Click → navigate to show view

### Show (`/admin/verifications/:id`)

- Provider business info summary
- Current verification status
- All documents with status badges
- View/download (signed URL, 5 min expiry)
- Approve / Reject buttons for pending docs
- Reject modal for rejection reason
- "Verify Provider" / "Unverify Provider" buttons

### Events

```elixir
handle_event("approve_document", %{"id" => id}, socket)
handle_event("reject_document", %{"id" => id, "reason" => reason}, socket)
handle_event("verify_provider", %{"id" => provider_id}, socket)
handle_event("unverify_provider", %{"id" => provider_id}, socket)
```

---

## 8. Program Creation Guard

### Event-Driven In-Memory Projection

`lib/klass_hero/program_catalog/adapters/driven/projections/verified_providers.ex`

GenServer that:
- On init: bootstrap query via `Identity.list_verified_provider_ids/0`, stores in MapSet
- Subscribes to `integration:identity:provider_verified` and `provider_unverified`
- Updates MapSet on events
- Exposes `verified?/1` for checking

### Program Catalog Use Case

```elixir
def execute(%{provider_id: provider_id} = params) do
  with :ok <- ensure_verified(provider_id),
       # ... rest of creation logic

defp ensure_verified(provider_id) do
  if VerifiedProviders.verified?(provider_id),
    do: :ok,
    else: {:error, :provider_not_verified}
end
```

### Supervision

Add `VerifiedProviders` to Program Catalog supervision tree.

### Overview Tab

- Show real verification status from ProviderProfile
- Badge: "Verified" (green) or "Pending Verification" (yellow)
- CTA for unverified: "Complete verification to create programs" → `/provider/settings`

### UI Guard

"New Program" button disabled for unverified providers with tooltip.

---

## Design Decisions

1. **Storage in Shared** — Cross-cutting infrastructure, like event publishing
2. **MinIO for integration tests** — Real S3 confidence, stub for fast unit tests
3. **is_admin boolean** — Orthogonal to role, simple access control
4. **Simple document lifecycle** — pending → approved/rejected, no resubmission
5. **Separate document and provider actions** — Audit trail, granular control
6. **Upload use cases in Identity** — Domain operations, not generic infrastructure
7. **Event-driven verification projection** — Decoupled contexts, no runtime cross-context calls
