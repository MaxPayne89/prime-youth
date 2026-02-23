# CSV Import Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Backend service that parses a CSV file and creates BulkEnrollmentInvite records in the database.

**Architecture:** Domain services (CsvParser, ImportRowValidator) handle pure parsing/validation. A use case orchestrates the pipeline. Persistence goes through a port → adapter. Program lookup uses a direct schemaless DB query (ACL pattern) to avoid the ProgramCatalog ↔ Enrollment dependency cycle.

**Tech Stack:** Elixir 1.20, NimbleCSV, Ecto.Multi, PostgreSQL

**Design doc:** `docs/plans/2026-02-21-csv-import-backend-design.md`

---

### Task 0: Add NimbleCSV dependency

**Files:**
- Modify: `mix.exs`

**Step 1:** Add `{:nimble_csv, "~> 1.0"}` to deps in `mix.exs` (after the `:jason` line).

**Step 2:** Run `mix deps.get`

**Step 3:** Commit

```bash
git add mix.exs mix.lock
git commit -m "chore: add nimble_csv dependency (#176)"
```

---

### Task 1: CsvParser domain service

**Files:**
- Create: `lib/klass_hero/enrollment/domain/services/csv_parser.ex`
- Create: `test/klass_hero/enrollment/domain/services/csv_parser_test.exs`

A pure domain service. No DB, no Ecto. Takes CSV binary → returns `{:ok, [row_map]}` or `{:error, [{row, reason}]}`.

**What it does:**
- Defines a NimbleCSV parser for RFC 4180 CSV
- Maps verbose CSV headers to internal atom keys via a `@header_mapping` module attribute
- Parses dates from `M/D/YYYY` and `MM/DD/YYYY` formats
- Maps "Yes"/"No"/empty to booleans
- Parses grade as integer (or nil)
- Trims whitespace from all strings, nils empty strings
- Returns row number (1-indexed, header excluded) with each error

**Tests should cover:**
- Happy path: valid CSV binary → list of correctly typed row maps
- Date parsing: `1/1/2016`, `09/23/2017`, `03/09/2018` all parse correctly
- Boolean mapping: "Yes" → true, "No" → false, "" → false
- Grade parsing: "3" → 3, "" → nil
- Whitespace trimming: `"Maxim "` → `"Maxim"`
- Error: empty/malformed CSV → parse error
- Error: missing required headers → error with details
- Quoted fields with commas parse correctly (e.g. `"2HB - BIS, Thursday"`)

**Commit:** `feat(enrollment): add CsvParser domain service (#176)`

---

### Task 2: ImportRowValidator domain service

**Files:**
- Create: `lib/klass_hero/enrollment/domain/services/import_row_validator.ex`
- Create: `test/klass_hero/enrollment/domain/services/import_row_validator_test.exs`

Pure domain service. Takes a parsed row map + context → `{:ok, validated_row}` or `{:error, [{field, message}]}`.

**Context shape:** `%{provider_id: "uuid", programs_by_title: %{"Title" => "uuid"}}`

**Validations:**
- Required: `child_first_name`, `child_last_name`, `child_date_of_birth`, `guardian_email`, `program_name`
- Email format: `guardian_email` must match `~r/^[^@,;\s]+@[^@,;\s]+$/`; `guardian2_email` if non-nil
- Program lookup: `program_name` must exist in `programs_by_title` map
- Date of birth: must be `%Date{}` in the past (parser already converts)
- School grade: 1-13 if present

**On success:** Returns the row map enriched with `:program_id` and `:provider_id`, with `:program_name`, `:instructor_name`, `:season` removed (not stored on invite, season lives on Program).

Actually, `:season` is NOT on the invite schema. But `:instructor_name` isn't either. These CSV columns are for matching/context only, not persisted on the invite. The validator strips them after validation.

**Tests should cover:**
- Happy path: valid row + matching program → enriched row
- Missing required field → error
- Bad email format → error
- Unknown program name → error
- Future DOB → error
- Grade out of range → error
- Optional fields nil → still valid
- Second guardian email validated when present

**Commit:** `feat(enrollment): add ImportRowValidator domain service (#176)`

---

### Task 3: ForStoringBulkEnrollmentInvites port

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`

Port behavior with two callbacks:

```elixir
@callback create_batch([map()]) :: {:ok, non_neg_integer()} | {:error, term()}
@callback list_existing_keys_for_programs([binary()]) :: MapSet.t()
```

`create_batch/1` — inserts all invite records atomically. Returns `{:ok, count}`.

`list_existing_keys_for_programs/1` — returns MapSet of `{program_id, email, first, last}` tuples for duplicate detection.

**No tests needed** — it's a behaviour definition.

**Commit:** `feat(enrollment): add ForStoringBulkEnrollmentInvites port (#176)`

---

### Task 4: BulkEnrollmentInviteRepository adapter

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

Implements the port.

**`create_batch/1`:** Uses `Ecto.Multi` to insert all rows. Each row goes through `BulkEnrollmentInviteSchema.import_changeset/2`. If any changeset fails, the whole transaction rolls back. Returns `{:ok, count}`.

**`list_existing_keys_for_programs/1`:** Queries `bulk_enrollment_invites` table, selects `{program_id, guardian_email, child_first_name, child_last_name}`, returns as MapSet.

**Tests should cover:**
- `create_batch` with valid rows → all inserted, count matches
- `create_batch` with invalid row → transaction rolled back, nothing persisted
- `list_existing_keys_for_programs` returns existing keys
- `list_existing_keys_for_programs` with no matching programs → empty MapSet

**Commit:** `feat(enrollment): add BulkEnrollmentInviteRepository adapter (#176)`

---

### Task 5: ProgramLookupACL adapter

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_resolving_program_catalog.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl_test.exs`

**IMPORTANT:** ProgramCatalog depends on Enrollment (dependency cycle). This ACL must use **direct schemaless DB queries** on the `programs` table, NOT the ProgramCatalog facade. Follow the pattern in `ProgramScheduleACL`.

**Port:** `ForResolvingProgramCatalog`
```elixir
@callback list_program_titles_for_provider(binary()) :: %{String.t() => binary()}
```

Returns `%{"Ballsports & Parkour" => "uuid", "Organic Arts" => "uuid"}`.

**Adapter:** Schemaless query:
```elixir
from(p in "programs",
  where: p.provider_id == type(^provider_id, :binary_id),
  select: {p.title, type(p.id, :binary_id)}
)
```

Also handle programs without a provider (community programs) — if the CSV contains programs that belong to NO provider, we need a decision. For now: only match programs belonging to the uploading provider.

**Tests should cover:**
- Returns title→id map for provider's programs
- Excludes programs from other providers
- Returns empty map when provider has no programs

**Commit:** `feat(enrollment): add ProgramCatalogACL for program lookup (#176)`

---

### Task 6: ImportEnrollmentCsv use case

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/import_enrollment_csv.ex`
- Create: `test/klass_hero/enrollment/application/use_cases/import_enrollment_csv_test.exs`

Orchestrates the full pipeline:

1. Parse CSV via `CsvParser.parse/1`
2. Load program lookup via `@program_catalog_acl.list_program_titles_for_provider/1`
3. Validate each row via `ImportRowValidator.validate/2`
4. Deduplicate within batch
5. Check existing invites via `@invite_repository.list_existing_keys_for_programs/1`
6. If errors → `{:error, error_report}`
7. If valid → `@invite_repository.create_batch/1`
8. Return `{:ok, %{created: count}}`

**Config wiring:** Add to `config/config.exs` under `:enrollment`:
```elixir
for_storing_bulk_enrollment_invites: BulkEnrollmentInviteRepository,
for_resolving_program_catalog: ProgramCatalogACL
```

**Tests should cover:**
- Happy path: valid CSV + existing programs → invites created
- Parse error → error report with row numbers
- Validation error → error report with field errors
- Duplicate within batch → flagged
- Duplicate against existing DB records → flagged
- All-or-nothing: one bad row means nothing persisted
- Real CSV template file as integration test input

**Commit:** `feat(enrollment): add ImportEnrollmentCsv use case (#176)`

---

### Task 7: Wire into Enrollment context facade

**Files:**
- Modify: `lib/klass_hero/enrollment.ex`

Add public function:
```elixir
def import_enrollment_csv(provider_id, csv_binary)
    when is_binary(provider_id) and is_binary(csv_binary) do
  ImportEnrollmentCsv.execute(provider_id, csv_binary)
end
```

**Commit:** `feat(enrollment): expose import_enrollment_csv on context facade (#176)`

---

### Task 8: Final verification

Run: `mix precommit`
Expected: 0 warnings, 0 failures

Run integration test with the actual CSV template file:
```elixir
csv = File.read!("program.import.template.Klass.Hero.csv")
Enrollment.import_enrollment_csv(provider_id, csv)
```

(This happens in a test, not manually.)
