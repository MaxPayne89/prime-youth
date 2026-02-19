# Participant Restrictions Design

**Issue:** #151 — Add participant restrictions (age, gender, grade) to programs
**Date:** 2026-02-18

## Summary

Providers can restrict program enrollment by participant age (year+month granularity), gender, and school grade (Klasse 1-13). Eligibility is checked either at registration time or at program start date (provider's choice). Ineligible children cannot enroll.

## Decisions

- **Context ownership:** Enrollment context owns restriction rules (alongside existing capacity policy)
- **Cross-context integration:** ACL pattern — Enrollment defines ports, ACL adapters call Family and ProgramCatalog
- **Model structure:** Single `ParticipantPolicy` model (one row per program), flat fields
- **Age storage:** Total months (integers) — UI converts to/from year+month display
- **Gender values on Child:** `male`, `female`, `diverse`, `not_specified` (German legal standard + opt-out)
- **Gender restriction:** Provider multi-selects which genders are allowed (explicit, no ambiguity)
- **Grade system:** German Klasse 1-13 (integers)
- **Eligibility timing:** Single setting per program: `registration` or `program_start`

## Domain Models

### Family Context — Child (add fields)

New fields on existing `Child` model:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `gender` | `:string` | `"not_specified"` | One of: `male`, `female`, `diverse`, `not_specified` |
| `school_grade` | `:integer` | `nil` | Nullable, range 1-13 (Klasse 1-13) |

Migration: add columns to `children` table, backfill existing rows with defaults.

### Enrollment Context — ParticipantPolicy (new model)

```
ParticipantPolicy
  id               :binary_id (UUID)
  program_id       :binary_id (unique constraint)
  eligibility_at   :string — "registration" | "program_start"
  min_age_months   :integer | nil
  max_age_months   :integer | nil
  allowed_genders  {:array, :string} — subset of ["male","female","diverse","not_specified"]
  min_grade        :integer | nil (1-13)
  max_grade        :integer | nil (1-13)
  inserted_at      :utc_datetime
  updated_at       :utc_datetime
```

**Semantics:**
- Empty `allowed_genders` list = no gender restriction
- `nil` age bounds = no age restriction on that end
- `nil` grade bounds = no grade restriction on that end
- All nil/empty = policy exists but imposes no restrictions

**Domain logic:**
- `ParticipantPolicy.new/1` — validates: min_age ≤ max_age, min_grade ≤ max_grade, genders are valid values
- `ParticipantPolicy.eligible?/2` — takes policy + participant map `%{age_months: int, gender: string, grade: int | nil}`, returns `{:ok, :eligible}` or `{:error, reasons}`
- `ParticipantPolicy.compute_age_months/2` — `date_of_birth` + reference date → age in months

## Ports

### ForManagingParticipantPolicies (new)

Mirrors `ForManagingEnrollmentPolicies`:
- `upsert(attrs)` → `{:ok, ParticipantPolicy.t()} | {:error, term()}`
- `get_by_program_id(program_id)` → `{:ok, ParticipantPolicy.t()} | {:error, :not_found}`
- `get_policies_by_program_ids(program_ids)` → `%{program_id => ParticipantPolicy.t()}`

### ForResolvingParticipantDetails (ACL port — new)

Enrollment's view of a child's eligibility-relevant data:
- `get_participant_details(child_id)` → `{:ok, %{date_of_birth: Date.t(), gender: String.t(), school_grade: integer() | nil}} | {:error, :not_found}`

ACL adapter calls `Family.get_child/1`, translates to enrollment's representation.

### ForResolvingProgramSchedule (ACL port — new)

Enrollment's view of program timing:
- `get_program_start_date(program_id)` → `{:ok, Date.t()} | {:error, :not_found}`

ACL adapter calls `ProgramCatalog.get_program_by_id/1`, extracts `start_date`.

## Use Cases

### CheckParticipantEligibility (new)

1. Load `ParticipantPolicy` for program (no policy → eligible)
2. Load participant details via ACL
3. Determine reference date: `eligibility_at == "program_start"` → load program start date via ACL; `"registration"` → `Date.utc_today()`
4. Compute age in months from `date_of_birth` + reference date
5. Call `ParticipantPolicy.eligible?/2`
6. Return `{:ok, :eligible}` or `{:error, :ineligible, reasons}`

### CreateEnrollment (modified)

Add eligibility check between existing booking-limit check and capacity check:
```
existing: validate parent → check booking limit → capacity check → create
new:      validate parent → check booking limit → check eligibility → capacity check → create
```

On failure: `{:error, :ineligible, reasons}`

## UI Changes

### Provider Dashboard — Program Form

New "Participant Restrictions" section below enrollment capacity:

- **Eligibility timing:** radio — "At registration" (default) / "At program start"
- **Age restriction:** year (0-18) + month (0-11) dropdowns for min/max
- **Gender restriction:** multi-select checkboxes (Male, Female, Diverse, Not specified)
- **Grade restriction:** dropdowns (Klasse 1-13) for min/max

Uses `participant_policy_form` assign backed by `Enrollment.new_participant_policy_changeset/1`. Saved on `save_program` event alongside program and enrollment policy.

### Booking LiveView — Eligibility Feedback

On `select_child` event:
1. Check eligibility via `Enrollment.check_participant_eligibility/2`
2. Eligible: green checkmark + "Meets all requirements"
3. Ineligible: red warning with specific reasons (e.g. "Minimum age is 5 years, child is 4 years 3 months")
4. Disable submit button when ineligible

Server-side enforcement in `CreateEnrollment` is the real gate.

### Program Detail Page

Show restriction info (read-only) so parents see requirements before starting enrollment. Small info card: "Requirements: Ages 5-8, Grades 1-3", etc.

### Children Settings (ChildrenLive)

Add to existing child form:
- Gender: select dropdown (4 options)
- School grade: optional select dropdown (Klasse 1-13, with empty option)

## Database Migration

Single migration:
1. Add `gender :string, default: "not_specified"` to `children`
2. Add `school_grade :integer` to `children`
3. Create `participant_policies` table with fields listed above
4. Unique index on `participant_policies(program_id)`

## Testing

- **Domain:** `ParticipantPolicy.eligible?/2` all combinations, validation, age calculation edge cases
- **Use case:** `CheckParticipantEligibility` with/without policy, eligible/ineligible, timing variants
- **Integration:** `CreateEnrollment` rejects ineligible, passes eligible
- **Persistence:** `ParticipantPolicyRepository` upsert/query
- **ACL:** Both adapters translate correctly
- **LiveView:** Provider form saves restrictions; Booking shows eligibility feedback and blocks ineligible; Children settings CRUD for new fields

## File Structure

```
lib/klass_hero/enrollment/
  domain/
    models/participant_policy.ex          # New domain model
    ports/for_managing_participant_policies.ex   # New port
    ports/for_resolving_participant_details.ex   # New ACL port
    ports/for_resolving_program_schedule.ex      # New ACL port
  application/
    use_cases/check_participant_eligibility.ex   # New use case
  adapters/
    driven/
      persistence/participant_policy_repository.ex  # New repo
      persistence/participant_policy_schema.ex      # New schema
      persistence/participant_policy_mapper.ex      # New mapper
      acl/participant_details_acl.ex                # New ACL adapter
      acl/program_schedule_acl.ex                   # New ACL adapter

lib/klass_hero/family/
  domain/models/child.ex                 # Add gender, school_grade fields
  adapters/driven/persistence/child_schema.ex  # Add columns

lib/klass_hero_web/
  live/booking_live.ex                   # Add eligibility check on child select
  live/provider/dashboard_live.ex        # Add participant restrictions form section
  live/settings/children_live.ex         # Add gender, grade fields to form
  components/booking_components.ex       # Add eligibility_status component
```
