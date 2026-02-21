# CSV Import Backend Design

**Date:** 2026-02-21
**Issue:** #176 — Add Bulk Enrollment List for Providers
**Status:** Approved
**Scope:** Backend CSV parsing, validation, and BulkEnrollmentInvite persistence. No emails, no UI, no registration flow.

## Data Flow

```
CSV binary
  → CsvParser.parse/1 (domain service, pure)
  → [row_maps]
  → ImportRowValidator.validate/2 per row (domain service, pure)
  → Use case checks duplicates (in-batch + existing via port)
  → ForStoringBulkEnrollmentInvites.create_batch/1 (port → adapter)
  → BulkEnrollmentInvite records with status: "pending"
```

## Dependencies

Add `nimble_csv` as a direct dependency. Needed for proper RFC 4180 CSV parsing (quoted fields with commas).

## Layer 1: CsvParser (Domain Service)

**File:** `lib/klass_hero/enrollment/domain/services/csv_parser.ex`

Pure function. Takes CSV binary, returns parsed row maps or errors.

**Responsibilities:**
- Map verbose CSV headers to internal field atoms (hardcoded mapping, CSV shape is fixed)
- Parse dates from mixed formats (`1/1/2016`, `09/23/2017`)
- Map "Yes"/"No"/empty to booleans for medical and consent fields
- Parse grade as integer
- Trim whitespace from all string fields
- Return `{:ok, [row_map]}` or `{:error, [{row_number, reason}]}`

**Header mapping:**

| CSV Header | Internal Field |
|---|---|
| Participant information: First name | `:child_first_name` |
| Participant information: Last name | `:child_last_name` |
| Participant information: Date of birth | `:child_date_of_birth` |
| Parent/guardian information: First name | `:guardian_first_name` |
| Parent/guardian information: Last name | `:guardian_last_name` |
| Parent/guardian information: Email address | `:guardian_email` |
| Parent/guardian 2 information: First name | `:guardian2_first_name` |
| Parent/guardian 2 information: Last name | `:guardian2_last_name` |
| Parent/guardian 2 information: Email address | `:guardian2_email` |
| School information: Grade | `:school_grade` |
| School information: Name | `:school_name` |
| Medical/allergy information: Do you have... | (used to validate next field, not persisted) |
| Medical/allergy information: Medical conditions... | `:medical_conditions` |
| Medical/allergy information: Nut allergy | `:nut_allergy` |
| Photography/video release...marketing... | `:consent_photo_marketing` |
| Photography/video release...social media... | `:consent_photo_social_media` |
| Program | `:program_name` |
| Instructor | `:instructor_name` |
| Season | `:season` |

## Layer 2: ImportRowValidator (Domain Service)

**File:** `lib/klass_hero/enrollment/domain/services/import_row_validator.ex`

Pure function. Takes a parsed row + lookup context, returns validated row or field errors.

**Context input:** `%{provider_id: uuid, programs_by_title: %{"title" => "uuid"}}`

**Validations:**
- Required: `child_first_name`, `child_last_name`, `child_date_of_birth`, `guardian_email`, `program_name`
- Email format: `guardian_email` required; `guardian2_email` if present
- Program existence: `program_name` must exist in `programs_by_title`
- Date of birth: must be in the past
- School grade: 1-13 if present

**Output:** `{:ok, row_with_program_id}` or `{:error, [{field, message}]}`

Enriches the row with `:program_id` (resolved from name) and `:provider_id`.

## Layer 3: ImportEnrollmentCsv Use Case (Application)

**File:** `lib/klass_hero/enrollment/application/use_cases/import_enrollment_csv.ex`

Orchestrates the pipeline:

1. `CsvParser.parse(csv_binary)` → rows or parse errors
2. Load provider's programs via ACL → build `programs_by_title` map
3. `ImportRowValidator.validate(row, context)` per row → collect all errors
4. Deduplicate within batch (same program + email + child name)
5. Check existing invites via port → flag duplicates
6. If ANY errors → `{:error, error_report}`
7. If all valid → `port.create_batch(rows)` in transaction
8. Return `{:ok, %{created: count}}`

**All-or-nothing:** if any row fails, nothing is persisted.

**Error shape:**
```elixir
{:error, %{
  parse_errors: [{row, message}],
  validation_errors: [{row, [{field, message}]}],
  duplicate_errors: [{row, message}]
}}
```

## Layer 4: Port & Adapter

**Port:** `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`

```
create_batch([map()]) :: {:ok, non_neg_integer()} | {:error, term()}
list_existing_keys_for_programs([binary()]) :: MapSet.t()
```

**Adapter:** `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`

- `create_batch/1`: `Ecto.Multi` inserting all rows via `import_changeset/2`
- `list_existing_keys_for_programs/1`: SELECT on composite unique key columns, returns a MapSet of `{program_id, email, first, last}` tuples

**ACL:** `lib/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl.ex`

Calls `KlassHero.ProgramCatalog` public API to list provider's programs, returns `%{title => id}` map.

## Config

```elixir
config :klass_hero, :enrollment,
  for_storing_bulk_enrollment_invites: BulkEnrollmentInviteRepository,
  program_catalog_acl: ProgramCatalogAcl
```

## Not In Scope

- LiveView upload UI
- Email invite sending
- Parent registration flow from invite
- Provider enrollment list dashboard
- Status transitions beyond initial "pending"
