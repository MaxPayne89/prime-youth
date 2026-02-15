# Context: Provider

> The Provider context manages everything about activity providers — their business profiles, team members, and verification documents. It's the system of record for who is allowed to offer programs on the platform and whether they've been vetted by an admin.

## What This Context Owns

- **Domain Concepts:** ProviderProfile (aggregate root), StaffMember, VerificationDocument
- **Data:** `providers`, `staff_members`, `verification_documents` tables
- **Processes:** Provider onboarding (via registration event), staff team management, document submission & admin review, provider verification/unverification

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Provider Profile Management | Active | — |
| Staff Member Management | Active | — |
| Verification Document Workflow | Active | — |
| Provider Verification (Admin) | Active | — |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Accounts | `:user_registered` event | Creates a ProviderProfile if user selected "provider" role. Uses `identity_id` correlation, not a foreign key. Retry with 100ms backoff on transient errors. |
| Accounts | `:user_anonymized` event | No-op — provider profiles retain `business_name` for audit trail. |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Program Catalog (and others) | `:provider_verified` event | `provider_id`, `business_name`, `verified_at`, `admin_id` — signals a provider is now trusted to list programs. |
| Program Catalog (and others) | `:provider_unverified` event | `provider_id`, `business_name`, `admin_id` — signals verification has been revoked. |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| Provider Profile | A business entity that offers programs. One profile per registered provider user. |
| Identity ID | A correlation ID linking the provider profile to its user in the Accounts context, keeping the two contexts independent. |
| Staff Member | A team member (coach, instructor) who can be assigned to programs and shown to parents. |
| Verification Document | A file (business registration, insurance, ID, tax cert) submitted by a provider for admin review. |
| Verified | A provider whose identity and credentials have been approved by an admin. Only verified providers can list programs. |
| Subscription Tier | The provider's plan level — `starter`, `professional`, or `business_plus` — which determines entitlements like program slots. |
| Tags | Category labels on staff members drawn from the shared Categories vocabulary (e.g., "Sports", "Music"). |
| Qualifications | Freeform text entries on staff members (e.g., "First Aid", "UEFA B License"). |

## Business Decisions

- **Providers are created automatically** when a user registers with the "provider" role. There is no manual "create provider" admin action.
- **Website URLs must use HTTPS.** HTTP links are rejected at the domain level.
- **Verification documents always start as `pending`.** Only pending documents can be approved or rejected — there is no way to re-review a decided document.
- **Verification is idempotent.** Calling verify on an already-verified provider simply updates the audit trail (timestamp + admin ID).
- **Unverification clears the audit trail.** When a provider is unverified, `verified_at` and `verified_by_id` are wiped.
- **File existence is validated before preview.** The admin preview use case checks the file actually exists in storage before generating a signed URL, preventing broken previews.
- **Signed preview URLs expire after 15 minutes.**
- **Filename sanitization** strips all characters except alphanumeric, dots, underscores, and hyphens before storing verification documents.
- **Provider profiles survive user anonymization.** The `business_name` is retained for audit even if the linked user is anonymized.
- **Staff member tags are validated** against the shared Categories vocabulary. Qualifications are freeform.
- **Only `description` and `logo_url` are editable** on provider profiles after creation. Business name and other fields are set at registration.

## Assumptions & Open Questions

- [NEEDS INPUT] What happens to a provider's programs when they are unverified? Should programs be hidden, suspended, or left as-is?
- [NEEDS INPUT] Should there be a way to re-review a rejected verification document, or must the provider submit a new one?
- [NEEDS INPUT] Is there a maximum number of staff members per provider, or is it unlimited regardless of subscription tier?
- [NEEDS INPUT] Should provider profile edits (description, logo) require re-verification?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
