# Bulk Enrollment Domain Gaps Design

**Date:** 2026-02-21
**Issue:** #176 — Add Bulk Enrollment List for Providers
**Status:** Approved
**Scope:** Schema/domain changes required before building the CSV import feature

## Context

Providers upload a CSV of existing students to bulk-enroll them. The CSV shape is fixed (19 columns). Comparing it against our domain revealed 6 gaps that must be resolved before any import feature work.

CSV template: `program.import.template.Klass.Hero.csv` (root of repo)

## Decisions

### 1. Children ↔ Parents: Many-to-Many Join Table

**Problem:** `children.parent_id` supports one parent. CSV has Parent 1 + Parent 2.

**Solution:** New `children_guardians` join table.

```
children_guardians
├── id (binary_id, PK)
├── child_id (FK → children)
├── guardian_id (FK → parents)
├── relationship (string: "parent", "guardian", "other")
├── is_primary (boolean, default: false)
├── inserted_at / updated_at
└── UNIQUE(child_id, guardian_id)
```

**Migration path:**
1. Create `children_guardians` table
2. Migrate existing `children.parent_id` rows into join table (with `is_primary: true`)
3. Drop `parent_id` from `children`

**Impact:**
- New `ChildGuardianSchema` in Family context
- `ChildSchema` loses `parent_id`, gains `has_many :children_guardians`
- `ParentProfileSchema` gains `has_many :children_guardians`
- `EnrollmentSchema.parent_id` unchanged — refers to the acting guardian who enrolled

### 2. Season Field on Program

**Problem:** No season concept in domain. CSV has "Berlin International School 24/25: Semester 2".

**Solution:** Add `season` string field (nullable, max 255) to `programs` table. Freeform label, no validation beyond length.

### 3. School Name on Child

**Problem:** `ChildSchema` has `school_grade` but no school name. CSV provides it.

**Solution:** Add `school_name` string field (nullable, max 255) to `children` table. Freeform string, no normalization.

### 4. BulkEnrollmentInvite Entity

**Problem:** No invite tracking. Enrollments go straight to pending/confirmed/completed/cancelled. Issue wants invite → registered → enrolled lifecycle.

**Solution:** New `bulk_enrollment_invites` table in Enrollment context. Stores raw CSV data as a staging record. Real domain entities (User, ParentProfile, Child, Enrollment, Consents) are created when the parent acts on the invite.

```
bulk_enrollment_invites
├── id (binary_id, PK)
├── program_id (FK → programs)
├── provider_id (FK → provider_profiles)
├── child_first_name (string, required)
├── child_last_name (string, required)
├── child_date_of_birth (date, required)
├── guardian_email (string, required)
├── guardian_first_name (string)
├── guardian_last_name (string)
├── guardian2_email (string, nullable)
├── guardian2_first_name (string, nullable)
├── guardian2_last_name (string, nullable)
├── school_grade (integer, nullable)
├── school_name (string, nullable)
├── medical_conditions (string, nullable)
├── nut_allergy (boolean, default: false)
├── consent_photo_marketing (boolean, default: false)
├── consent_photo_social_media (boolean, default: false)
├── status (string: "pending", "invite_sent", "registered", "enrolled", "failed")
├── invite_token (string, unique)
├── invite_sent_at (utc_datetime, nullable)
├── registered_at (utc_datetime, nullable)
├── enrolled_at (utc_datetime, nullable)
├── enrollment_id (FK → enrollments, nullable)
├── error_details (string, nullable)
├── inserted_at / updated_at
└── UNIQUE(program_id, guardian_email, child_first_name, child_last_name)
```

**Status flow:** `pending` → `invite_sent` → `registered` → `enrolled` (+ `failed`)

**Design rationale:**
- Denormalized on purpose — staging record stores raw CSV data
- `invite_token` — unique token in email link, ties parent back to specific invite
- `enrollment_id` — backlink to real enrollment once created
- Uniqueness constraint prevents duplicate invites per child+parent+program

### 5. Photo Consent Split

**Problem:** Single `"photo"` consent type. CSV distinguishes marketing materials vs social media.

**Solution:** Replace `"photo"` with `"photo_marketing"` + `"photo_social_media"`.

New valid types: `["provider_data_sharing", "photo_marketing", "photo_social_media", "medical", "participation"]`

No existing `photo` consent records to migrate (verified via SQL query).

### 6. Parent Name Handling

**Problem:** CSV has separate first/last name. User.name is a single field.

**Solution:** Concatenate during import (`"#{first} #{last}"` → `User.name`). No schema change needed.

## Out of Scope

These are part of the import feature, not the domain gap resolution:
- CSV upload UI
- Email invite sending
- Parent registration flow from invite link
- Provider enrollment list dashboard
- CSV validation and error reporting UI
