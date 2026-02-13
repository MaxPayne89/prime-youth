# Context: Family

> Manages everything about a parent's family — their profile, their children's information, and the consents they grant for each child. This context is the single source of truth for parent and child data, and it handles GDPR data export and anonymization for family-owned personal information.

## What This Context Owns

- **Domain Concepts:** ParentProfile (aggregate root), Child, Consent, ReferralCode
- **Data:** `parent_profiles`, `children`, `consents` tables
- **Processes:** Child CRUD, consent grant/withdraw lifecycle, GDPR anonymization cascade, GDPR data export, referral code generation, activity goal calculation

## Key Features

| Feature | Status | Doc |
|---|---|---|
| Child Management | Active | [child-management](features/child-management.md) |
| Consent Management | Active | [consent-management](features/consent-management.md) |
| Parent Profile Creation | Active | [parent-profile-creation](features/parent-profile-creation.md) |
| GDPR Data Anonymization | Active | [gdpr-anonymization](features/gdpr-anonymization.md) |
| GDPR Data Export | Active | [gdpr-data-export](features/gdpr-data-export.md) |
| Referral Codes | Active | [referral-codes](features/referral-codes.md) |
| Activity Goal Calculation | Active | [activity-goal](features/activity-goal.md) |

## Inbound Communication

| From Context | Event / Call | What It Triggers |
|---|---|---|
| Accounts | `user_registered` (with `"parent"` in intended_roles) | Creates a new ParentProfile automatically |
| Accounts | `user_anonymized` | Anonymizes all children and deletes all consents for the user's family, then publishes `child_data_anonymized` per child |

## Outbound Communication

| To Context | Event / Call | What It Provides |
|---|---|---|
| Participation | `child_data_anonymized` (integration event, critical) | Notifies that a child's PII was anonymized — Participation must anonymize its own child-related data |
| Enrollment | `ParentProfileSchema` (exported schema) | Enrollment joins on parent_profile for enrollment records |

## Ubiquitous Language

| Term | Meaning |
|---|---|
| **Parent Profile** | A parent's account in the Family context, linked to an Accounts user via `identity_id` (correlation ID, not FK). Contains display name, phone, location, notification preferences, and subscription tier. |
| **Child** | A child registered under a parent. Has name, date of birth, and optional emergency contact, support needs, and allergy information. |
| **Consent** | A record of a parent granting (or withdrawing) permission for a specific type of activity involving their child. Types: `photo`, `medical`, `participation`, `provider_data_sharing`. |
| **Active Consent** | A consent record where `withdrawn_at` is nil — the parent has not revoked it. |
| **Referral Code** | A code in the format `FIRSTNAME-LOCATION-YY` used for referral programs. Generated from the parent's name. |
| **Subscription Tier** | A parent's subscription level: `:explorer` or `:active`. Determines feature access. |
| **Anonymization** | The GDPR process of replacing a child's personal data (names, DOB, emergency contact, support needs, allergies) with placeholder values. The domain model defines what "anonymized" means. |

## Business Decisions

- **One parent profile per user.** A user can only have one parent profile (enforced by unique constraint on `identity_id`). Duplicate creation attempts are treated as idempotent.
- **Consent is per-child, per-type.** Only one active consent per (child, consent_type) combination at a time. Granting when already active returns `:already_active`.
- **Consent types are enumerated.** Only four valid types: `photo`, `medical`, `participation`, `provider_data_sharing`. Invalid types are rejected at domain validation.
- **Consent history is preserved.** Multiple consent records exist per (child, type) for audit trail. Withdrawing sets `withdrawn_at` rather than deleting.
- **Authorization fails closed.** `child_belongs_to_parent?` and `child_has_active_consent?` return `false` on any error, never granting access on failure.
- **GDPR anonymization is cascading and critical.** When a user is anonymized, each child's data is anonymized and a `child_data_anonymized` event (marked `:critical`) is published per child. If any step fails, the cascade halts.
- **Date of birth must be in the past.** Children cannot have a future date of birth.
- **Names have length limits.** First and last name: 1-100 characters. Emergency contact: max 255 characters.

## Assumptions & Open Questions

- The `ParentProfileSchema` is exported to Enrollment for join queries — this is a pragmatic coupling. If this becomes problematic, consider replacing with an anti-corruption layer.
- Activity goal calculation delegates to `Shared.ActivityGoalCalculator` — it's unclear whether this should live in Family or remain shared. `[NEEDS INPUT]`
- No update or delete operations exist for parent profiles yet. `[NEEDS INPUT]` — is this intentional?
- Referral code generation uses a fixed location default of "BERLIN". `[NEEDS INPUT]` — should this be configurable per user?

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
