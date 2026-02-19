# Participant Restrictions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Providers can restrict program enrollment by age, gender, and grade (Klasse 1-13). Ineligible children cannot enroll.

**Architecture:** New `ParticipantPolicy` domain model in Enrollment context (sibling to `EnrollmentPolicy`). Two ACL adapters bridge to Family (child details) and ProgramCatalog (start date). `CheckParticipantEligibility` use case enforces rules. UI in provider dashboard (config) and booking flow (feedback).

**Tech Stack:** Elixir/Phoenix, Ecto, LiveView, PostgreSQL

**Design doc:** `docs/plans/2026-02-18-participant-restrictions-design.md`

---

## Task 1: Add gender and school_grade to Child (Family context)

**Files:**
- Modify: `lib/klass_hero/family/domain/models/child.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/schemas/child_schema.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/mappers/child_mapper.ex`
- Create: `priv/repo/migrations/TIMESTAMP_add_gender_and_grade_to_children.exs`
- Modify: `test/klass_hero/family/domain/models/child_test.exs`
- Modify: `test/support/factory.ex` (child factories)

**Step 1: Write migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddGenderAndGradeToChildren do
  use Ecto.Migration

  def change do
    alter table(:children) do
      add :gender, :string, default: "not_specified", null: false
      add :school_grade, :integer
    end

    create constraint(:children, :valid_gender,
             check: "gender IN ('male', 'female', 'diverse', 'not_specified')"
           )

    create constraint(:children, :valid_school_grade,
             check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
           )
  end
end
```

Run: `mix ecto.gen.migration add_gender_and_grade_to_children` then replace content.

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds, no errors.

**Step 3: Update Child domain model**

In `lib/klass_hero/family/domain/models/child.ex`:
- Add `:gender` and `:school_grade` to `defstruct` (not in `@enforce_keys` — both have defaults/nil)
- Add to `@type t` spec
- Add `@valid_genders ~w(male female diverse not_specified)`
- Add `gender` validation in `new/1` — default to `"not_specified"` if nil, reject invalid values
- `school_grade` validation — nil ok, must be 1-13 if present
- Add `age_in_months/1` function: computes from `date_of_birth` relative to a given date
- Add `age_in_months/2` variant: takes `child, reference_date`

```elixir
@valid_genders ~w(male female diverse not_specified)

def valid_genders, do: @valid_genders

@doc "Computes age in whole months from date_of_birth to reference_date."
@spec age_in_months(t(), Date.t()) :: non_neg_integer()
def age_in_months(%__MODULE__{date_of_birth: dob}, reference_date) do
  year_months = (reference_date.year - dob.year) * 12
  month_diff = reference_date.month - dob.month

  # Trigger: child hasn't had their birthday this month yet
  # Why: if reference day < birth day, they haven't completed the current month
  # Outcome: subtract one month to avoid rounding up
  day_adjustment = if reference_date.day < dob.day, do: -1, else: 0

  max(year_months + month_diff + day_adjustment, 0)
end
```

**Step 4: Update ChildSchema**

In `lib/klass_hero/family/adapters/driven/persistence/schemas/child_schema.ex`:
- Add `field :gender, :string, default: "not_specified"` and `field :school_grade, :integer` to schema
- Add `:gender` and `:school_grade` to `@optional_fields`
- Add validations in `shared_validations/1`: `validate_inclusion(:gender, Child.valid_genders())`, `validate_number(:school_grade, greater_than_or_equal_to: 1, less_than_or_equal_to: 13)`
- Add `check_constraint(:valid_gender)` and `check_constraint(:valid_school_grade)`

**Step 5: Update ChildMapper**

In the child mapper, add `:gender` and `:school_grade` to both `to_domain/1` and `to_schema_attrs/1` mappings.

**Step 6: Update factory**

In `test/support/factory.ex`, update `child_schema_factory` and `child_factory`:
- Add `gender: "not_specified"` (or sequence through values for variety)
- Add `school_grade: nil`

**Step 7: Write tests for new Child fields**

In `test/klass_hero/family/domain/models/child_test.exs`:
- Test `Child.new/1` with valid gender values
- Test `Child.new/1` rejects invalid gender
- Test `Child.new/1` defaults gender to "not_specified" when nil
- Test `Child.new/1` accepts valid school_grade (1-13) and nil
- Test `Child.new/1` rejects school_grade outside 1-13
- Test `Child.age_in_months/2` — basic case, boundary cases (day before/after birthday)

**Step 8: Run tests**

Run: `mix test test/klass_hero/family/ --max-failures 5`
Expected: All pass.

**Step 9: Commit**

```bash
git add lib/klass_hero/family/ priv/repo/migrations/*gender* test/klass_hero/family/ test/support/factory.ex
git commit -m "feat: add gender and school_grade fields to Child (#151)"
```

---

## Task 2: ParticipantPolicy domain model (Enrollment context)

**Files:**
- Create: `lib/klass_hero/enrollment/domain/models/participant_policy.ex`
- Create: `test/klass_hero/enrollment/domain/models/participant_policy_test.exs`

**Step 1: Write tests for ParticipantPolicy**

Test file: `test/klass_hero/enrollment/domain/models/participant_policy_test.exs`

Test cases for `ParticipantPolicy.new/1`:
- Valid policy with all fields
- Valid policy with no restrictions (all nil/empty)
- Rejects min_age > max_age
- Rejects min_grade > max_grade
- Rejects invalid gender values in allowed_genders
- Requires program_id
- Defaults eligibility_at to "registration"

Test cases for `ParticipantPolicy.eligible?/2`:
- No restrictions (all nil/empty) → eligible
- Age within range → eligible
- Age below min → ineligible with reason
- Age above max → ineligible with reason
- Gender in allowed list → eligible
- Gender not in allowed list → ineligible with reason
- Empty allowed_genders → eligible (no restriction)
- Grade within range → eligible
- Grade below min → ineligible
- Grade above max → ineligible
- Grade nil when restriction exists → ineligible (child has no grade set)
- Multiple failures → all reasons returned
- Only min_age set (no max) → eligible if above min
- Only max_age set (no min) → eligible if below max

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/enrollment/domain/models/participant_policy_test.exs --max-failures 1`
Expected: Compilation error — module doesn't exist yet.

**Step 3: Implement ParticipantPolicy**

Create `lib/klass_hero/enrollment/domain/models/participant_policy.ex`:

```elixir
defmodule KlassHero.Enrollment.Domain.Models.ParticipantPolicy do
  @moduledoc """
  Domain model representing participant eligibility restrictions for a program.

  Owned by the Enrollment context. Providers configure age, gender, and grade
  restrictions; the enrollment context enforces these during enrollment.

  ## Restriction Semantics

  - `min_age_months` / `max_age_months` — age range in total months. nil = no bound.
  - `allowed_genders` — list of allowed gender values. Empty list = no restriction.
  - `min_grade` / `max_grade` — school grade range (Klasse 1-13). nil = no bound.
  - `eligibility_at` — when to evaluate: "registration" (today) or "program_start".
  """

  @enforce_keys [:program_id]

  defstruct [
    :id,
    :program_id,
    :min_age_months,
    :max_age_months,
    :min_grade,
    :max_grade,
    :inserted_at,
    :updated_at,
    eligibility_at: "registration",
    allowed_genders: []
  ]

  @type t :: %__MODULE__{...}

  @valid_genders ~w(male female diverse not_specified)
  @valid_eligibility ~w(registration program_start)

  def valid_genders, do: @valid_genders
  def valid_eligibility_options, do: @valid_eligibility

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    # validation chain similar to EnrollmentPolicy.new/1
    # validates: program_id required, min_age <= max_age, min_grade <= max_grade,
    # allowed_genders subset of valid, eligibility_at valid
  end

  @spec eligible?(t(), map()) :: {:ok, :eligible} | {:error, [String.t()]}
  def eligible?(%__MODULE__{} = policy, %{age_months: _, gender: _, grade: _} = participant) do
    # check age, gender, grade — collect all failing reasons
  end
end
```

Implementation details:
- `eligible?/2` takes `%{age_months: integer, gender: string, grade: integer | nil}`
- Each check is a separate function returning `[]` or `["reason"]`
- Combine all reasons; if empty → `{:ok, :eligible}`, else `{:error, reasons}`

**Step 4: Run tests**

Run: `mix test test/klass_hero/enrollment/domain/models/participant_policy_test.exs`
Expected: All pass.

**Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/domain/models/participant_policy.ex test/klass_hero/enrollment/domain/models/participant_policy_test.exs
git commit -m "feat: add ParticipantPolicy domain model with eligibility logic (#151)"
```

---

## Task 3: ParticipantPolicy persistence (schema, repo, mapper, migration)

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_participant_policies.exs`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/participant_policy_schema.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/mappers/participant_policy_mapper.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/participant_policy_repository.ex`
- Create: `lib/klass_hero/enrollment/domain/ports/for_managing_participant_policies.ex`
- Modify: `config/config.exs` — add `:for_managing_participant_policies` under `:enrollment`
- Create: `test/klass_hero/enrollment/adapters/driven/persistence/schemas/participant_policy_schema_test.exs`
- Create: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/participant_policy_repository_test.exs`
- Create: `test/klass_hero/enrollment/adapters/driven/persistence/mappers/participant_policy_mapper_test.exs`

**Step 1: Write migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateParticipantPolicies do
  use Ecto.Migration

  def change do
    create table(:participant_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all), null: false
      add :eligibility_at, :string, default: "registration", null: false
      add :min_age_months, :integer
      add :max_age_months, :integer
      add :allowed_genders, {:array, :string}, default: [], null: false
      add :min_grade, :integer
      add :max_grade, :integer
      timestamps(type: :utc_datetime)
    end

    create unique_index(:participant_policies, [:program_id])

    create constraint(:participant_policies, :valid_eligibility_at,
             check: "eligibility_at IN ('registration', 'program_start')"
           )

    create constraint(:participant_policies, :valid_age_range,
             check: "min_age_months IS NULL OR max_age_months IS NULL OR min_age_months <= max_age_months"
           )

    create constraint(:participant_policies, :valid_grade_range,
             check: "min_grade IS NULL OR max_grade IS NULL OR min_grade <= max_grade"
           )

    create constraint(:participant_policies, :valid_age_months,
             check: "min_age_months IS NULL OR min_age_months >= 0"
           )

    create constraint(:participant_policies, :valid_grade_bounds,
             check: "(min_grade IS NULL OR (min_grade >= 1 AND min_grade <= 13)) AND (max_grade IS NULL OR (max_grade >= 1 AND max_grade <= 13))"
           )
  end
end
```

Run: `mix ecto.gen.migration create_participant_policies` then replace. Run `mix ecto.migrate`.

**Step 2: Create port**

`lib/klass_hero/enrollment/domain/ports/for_managing_participant_policies.ex` — follow exact pattern of `ForManagingEnrollmentPolicies`:
- `@callback upsert(attrs :: map()) :: {:ok, ParticipantPolicy.t()} | {:error, term()}`
- `@callback get_by_program_id(program_id :: binary()) :: {:ok, ParticipantPolicy.t()} | {:error, :not_found}`
- `@callback get_policies_by_program_ids(program_ids :: [binary()]) :: %{binary() => ParticipantPolicy.t()}`

**Step 3: Create schema**

`lib/klass_hero/enrollment/adapters/driven/persistence/schemas/participant_policy_schema.ex` — follow `EnrollmentPolicySchema` pattern:
- Fields: `program_id :binary_id`, `eligibility_at :string`, `min_age_months :integer`, `max_age_months :integer`, `allowed_genders {:array, :string}`, `min_grade :integer`, `max_grade :integer`
- Changeset: cast all, require `program_id`, validate inclusion of `eligibility_at`, validate_number for age/grade fields, validate allowed_genders subset, validate min ≤ max for age and grade, unique_constraint on program_id, check_constraints

**Step 4: Create mapper**

`lib/klass_hero/enrollment/adapters/driven/persistence/mappers/participant_policy_mapper.ex` — follow `EnrollmentPolicyMapper` pattern:
- `to_domain/1` maps schema → `%ParticipantPolicy{}`
- `to_schema_attrs/1` extracts relevant keys from attrs map

**Step 5: Create repository**

`lib/klass_hero/enrollment/adapters/driven/persistence/repositories/participant_policy_repository.ex` — follow `EnrollmentPolicyRepository` pattern:
- `upsert/1` with `on_conflict: {:replace, [...all fields except id/program_id..., :updated_at]}, conflict_target: :program_id`
- `get_by_program_id/1`
- `get_policies_by_program_ids/1` — batch query

**Step 6: Wire up config**

In `config/config.exs`, add to the `:enrollment` config block:
```elixir
config :klass_hero, :enrollment,
  for_managing_enrollments: ...,
  for_managing_enrollment_policies: ...,
  for_managing_participant_policies:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.ParticipantPolicyRepository
```

**Step 7: Write tests**

- Schema test: valid changeset, missing program_id, invalid eligibility_at, invalid gender values, min > max age, min > max grade
- Mapper test: `to_domain/1` round-trip, `to_schema_attrs/1`
- Repository test: upsert creates, upsert updates (change values), get_by_program_id, get_by_program_id not_found, batch query

**Step 8: Run tests**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/ --max-failures 5`
Expected: All pass.

**Step 9: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_managing_participant_policies.ex \
  lib/klass_hero/enrollment/adapters/driven/persistence/schemas/participant_policy_schema.ex \
  lib/klass_hero/enrollment/adapters/driven/persistence/mappers/participant_policy_mapper.ex \
  lib/klass_hero/enrollment/adapters/driven/persistence/repositories/participant_policy_repository.ex \
  priv/repo/migrations/*participant_policies* \
  config/config.exs \
  test/klass_hero/enrollment/adapters/
git commit -m "feat: add ParticipantPolicy persistence layer (#151)"
```

---

## Task 4: ACL adapters (Family + ProgramCatalog bridges)

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_resolving_participant_details.ex`
- Create: `lib/klass_hero/enrollment/domain/ports/for_resolving_program_schedule.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/acl/participant_details_acl.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/acl/program_schedule_acl.ex`
- Modify: `config/config.exs` — add ACL adapter config entries
- Create: `test/klass_hero/enrollment/adapters/driven/acl/participant_details_acl_test.exs`
- Create: `test/klass_hero/enrollment/adapters/driven/acl/program_schedule_acl_test.exs`

**Step 1: Create ForResolvingParticipantDetails port**

```elixir
defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingParticipantDetails do
  @moduledoc """
  ACL port for resolving child eligibility data from outside the Enrollment context.

  Enrollment needs date_of_birth, gender, and school_grade to check eligibility.
  This port abstracts the source (Family context) behind a contract.
  """

  @type participant_details :: %{
    date_of_birth: Date.t(),
    gender: String.t(),
    school_grade: non_neg_integer() | nil
  }

  @callback get_participant_details(child_id :: binary()) ::
              {:ok, participant_details()} | {:error, :not_found}
end
```

**Step 2: Create ForResolvingProgramSchedule port**

```elixir
defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingProgramSchedule do
  @moduledoc """
  ACL port for resolving program schedule data from outside the Enrollment context.

  Enrollment needs the program start date for "at program start" eligibility checks.
  """

  @callback get_program_start_date(program_id :: binary()) ::
              {:ok, Date.t() | nil} | {:error, :not_found}
end
```

**Step 3: Implement ParticipantDetailsACL adapter**

`lib/klass_hero/enrollment/adapters/driven/acl/participant_details_acl.ex`:

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ParticipantDetailsACL do
  @moduledoc """
  ACL adapter that translates Family context child data into
  Enrollment's participant details representation.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForResolvingParticipantDetails

  alias KlassHero.Family

  @impl true
  def get_participant_details(child_id) do
    case Family.get_child_by_id(child_id) do
      {:ok, child} ->
        {:ok, %{
          date_of_birth: child.date_of_birth,
          gender: child.gender,
          school_grade: child.school_grade
        }}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
```

**Step 4: Implement ProgramScheduleACL adapter**

`lib/klass_hero/enrollment/adapters/driven/acl/program_schedule_acl.ex`:

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ProgramScheduleACL do
  @behaviour KlassHero.Enrollment.Domain.Ports.ForResolvingProgramSchedule

  alias KlassHero.ProgramCatalog

  @impl true
  def get_program_start_date(program_id) do
    case ProgramCatalog.get_program_by_id(program_id) do
      {:ok, program} -> {:ok, program.start_date}
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
```

**Step 5: Wire up config**

In `config/config.exs` under `:enrollment`:
```elixir
for_resolving_participant_details:
  KlassHero.Enrollment.Adapters.Driven.ACL.ParticipantDetailsACL,
for_resolving_program_schedule:
  KlassHero.Enrollment.Adapters.Driven.ACL.ProgramScheduleACL
```

**Step 6: Write tests**

Both ACL tests need DB (DataCase) since they call through to real repos:
- `ParticipantDetailsACL` test: insert child via factory, call `get_participant_details/1`, verify map shape. Test not_found.
- `ProgramScheduleACL` test: insert program via factory, call `get_program_start_date/1`, verify date. Test not_found. Test nil start_date.

**Step 7: Run tests**

Run: `mix test test/klass_hero/enrollment/adapters/driven/acl/ --max-failures 5`
Expected: All pass.

**Step 8: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_resolving_* \
  lib/klass_hero/enrollment/adapters/driven/acl/ \
  config/config.exs \
  test/klass_hero/enrollment/adapters/driven/acl/
git commit -m "feat: add ACL adapters for participant details and program schedule (#151)"
```

---

## Task 5: CheckParticipantEligibility use case

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/check_participant_eligibility.ex`
- Create: `test/klass_hero/enrollment/application/use_cases/check_participant_eligibility_test.exs`
- Modify: `lib/klass_hero/enrollment.ex` — add public API functions

**Step 1: Write tests**

`test/klass_hero/enrollment/application/use_cases/check_participant_eligibility_test.exs`:

Test cases (use DataCase, insert real data via factory):
- No policy exists for program → `{:ok, :eligible}`
- Policy exists, child meets all restrictions → `{:ok, :eligible}`
- Policy exists, child too young → `{:error, :ineligible, ["..."]}`
- Policy exists, child too old → `{:error, :ineligible, ["..."]}`
- Policy exists, gender not allowed → `{:error, :ineligible, ["..."]}`
- Policy exists, grade below min → `{:error, :ineligible, ["..."]}`
- Policy with `eligibility_at: "program_start"` — use program start_date for age calc
- Policy with `eligibility_at: "program_start"` and nil start_date — falls back to today
- Child not found → `{:error, :not_found}`
- Multiple failures returned together

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/enrollment/application/use_cases/check_participant_eligibility_test.exs --max-failures 1`
Expected: Fails (module doesn't exist).

**Step 3: Implement use case**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.CheckParticipantEligibility do
  @moduledoc """
  Checks whether a child is eligible to enroll in a program based on
  the program's participant policy (age, gender, grade restrictions).

  Returns {:ok, :eligible} when no policy exists or all checks pass.
  Returns {:error, :ineligible, reasons} with human-readable reason list.
  """

  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy
  alias KlassHero.Family.Domain.Models.Child

  require Logger

  @spec execute(binary(), binary()) ::
          {:ok, :eligible} | {:error, :ineligible, [String.t()]} | {:error, term()}
  def execute(program_id, child_id) do
    with {:ok, policy} <- load_policy(program_id),
         {:ok, details} <- participant_details_adapter().get_participant_details(child_id),
         {:ok, reference_date} <- resolve_reference_date(policy, program_id) do
      age_months = Child.age_in_months(%Child{date_of_birth: details.date_of_birth}, reference_date)

      participant = %{
        age_months: age_months,
        gender: details.gender,
        grade: details.school_grade
      }

      ParticipantPolicy.eligible?(policy, participant)
    end
  end

  # No policy → eligible (no restrictions configured)
  defp load_policy(program_id) do
    case policy_repo().get_by_program_id(program_id) do
      {:ok, policy} -> {:ok, policy}
      {:error, :not_found} -> {:ok, :eligible}
    end
  end

  # Short-circuit: load_policy returned :eligible directly
  # (pattern matched before with chain continues)

  defp resolve_reference_date(%ParticipantPolicy{eligibility_at: "program_start"}, program_id) do
    case program_schedule_adapter().get_program_start_date(program_id) do
      {:ok, nil} -> {:ok, Date.utc_today()}
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:ok, Date.utc_today()}
    end
  end

  defp resolve_reference_date(%ParticipantPolicy{eligibility_at: _}, _program_id) do
    {:ok, Date.utc_today()}
  end

  defp policy_repo do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_participant_policies]
  end

  defp participant_details_adapter do
    Application.get_env(:klass_hero, :enrollment)[:for_resolving_participant_details]
  end

  defp program_schedule_adapter do
    Application.get_env(:klass_hero, :enrollment)[:for_resolving_program_schedule]
  end
end
```

Note: The `load_policy` returning `{:ok, :eligible}` on not_found needs special handling — the `with` chain should short-circuit. Use a tagged tuple like `{:ok, {:no_policy}}` and handle before the `eligible?` call, or restructure as a `case` chain.

**Step 4: Add public API to Enrollment facade**

In `lib/klass_hero/enrollment.ex`:
- Add `alias KlassHero.Enrollment.Application.UseCases.CheckParticipantEligibility`
- Add function:

```elixir
@doc """
Checks whether a child is eligible for a program based on participant restrictions.

Returns {:ok, :eligible} when eligible or no policy exists.
Returns {:error, :ineligible, reasons} with human-readable reason list.
"""
def check_participant_eligibility(program_id, child_id) do
  CheckParticipantEligibility.execute(program_id, child_id)
end
```

- Add `set_participant_policy/1`, `get_participant_policy/1`, `new_participant_policy_changeset/1` functions (follow the enrollment policy pattern).
- Add `defp participant_policy_repo` helper.

**Step 5: Run tests**

Run: `mix test test/klass_hero/enrollment/application/use_cases/check_participant_eligibility_test.exs`
Expected: All pass.

**Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/application/use_cases/check_participant_eligibility.ex \
  lib/klass_hero/enrollment.ex \
  test/klass_hero/enrollment/application/use_cases/check_participant_eligibility_test.exs
git commit -m "feat: add CheckParticipantEligibility use case (#151)"
```

---

## Task 6: Enforce eligibility in CreateEnrollment

**Files:**
- Modify: `lib/klass_hero/enrollment/application/use_cases/create_enrollment.ex`
- Modify: `test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs`

**Step 1: Write tests for eligibility enforcement**

Add to `create_enrollment_test.exs`:

```elixir
describe "participant eligibility enforcement" do
  test "rejects enrollment when child is too young" do
    program = insert(:program_schema)
    # Child born recently — will be ~1 year old
    child = insert(:child_schema, date_of_birth: Date.add(Date.utc_today(), -365))

    # Set policy: min age 5 years (60 months)
    Enrollment.set_participant_policy(%{
      program_id: program.id,
      min_age_months: 60,
      eligibility_at: "registration"
    })

    parent = # ... setup parent with identity

    result = CreateEnrollment.execute(%{
      identity_id: parent_identity_id,
      program_id: program.id,
      child_id: child.id,
      payment_method: "card"
    })

    assert {:error, :ineligible, reasons} = result
    assert length(reasons) > 0
  end

  test "allows enrollment when child meets all restrictions" do
    # ... setup with eligible child
    assert {:ok, _enrollment} = CreateEnrollment.execute(params)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs --max-failures 1`
Expected: Fails — no eligibility check yet.

**Step 3: Add eligibility check to CreateEnrollment**

In `lib/klass_hero/enrollment/application/use_cases/create_enrollment.ex`, modify `create_enrollment_with_validation/2`:

```elixir
defp create_enrollment_with_validation(identity_id, params) do
  with {:ok, parent} <- validate_parent_profile(identity_id),
       :ok <- validate_booking_entitlement(parent),
       :ok <- validate_participant_eligibility(params[:program_id], params[:child_id]) do
    attrs = build_enrollment_attrs(params, parent.id)
    # ... rest unchanged
  end
end
```

Add private function:

```elixir
# Trigger: child may not meet program's age/gender/grade restrictions
# Why: enforce provider-configured eligibility rules before accepting enrollment
# Outcome: blocks ineligible children with human-readable reasons
defp validate_participant_eligibility(program_id, child_id) do
  case CheckParticipantEligibility.execute(program_id, child_id) do
    {:ok, :eligible} -> :ok
    {:error, :ineligible, reasons} -> {:error, :ineligible, reasons}
    {:error, reason} ->
      Logger.warning("[CreateEnrollment] Eligibility check failed unexpectedly",
        program_id: program_id,
        child_id: child_id,
        reason: inspect(reason)
      )
      # Trigger: ACL failure (child not found, etc.)
      # Why: fail open would be a safety risk — deny enrollment if we can't verify
      # Outcome: return processing_failed so UI shows generic error
      {:error, :processing_failed}
  end
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs`
Expected: All pass.

**Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/application/use_cases/create_enrollment.ex \
  test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs
git commit -m "feat: enforce participant eligibility in CreateEnrollment (#151)"
```

---

## Task 7: Children settings UI (add gender + grade fields)

**Files:**
- Modify: `lib/klass_hero_web/live/settings/children_live.ex`
- Modify: existing children LiveView tests (if any) or create new

**Step 1: Add gender and school_grade to ChildrenLive**

In `lib/klass_hero_web/live/settings/children_live.ex`:

- Add `:gender` and `:school_grade` to `@allowed_keys` (line 278)
- Add form fields in the render template, after date_of_birth and before emergency_contact:

```heex
<.input
  field={@form[:gender]}
  type="select"
  label={gettext("Gender")}
  options={[
    {gettext("Not specified"), "not_specified"},
    {gettext("Male"), "male"},
    {gettext("Female"), "female"},
    {gettext("Diverse"), "diverse"}
  ]}
/>

<.input
  field={@form[:school_grade]}
  type="select"
  label={gettext("School Grade (optional)")}
  prompt={gettext("No grade")}
  options={Enum.map(1..13, &{gettext("Klasse %{n}", n: &1), &1})}
/>
```

**Step 2: Test manually or write LiveView test**

Run: `mix test test/klass_hero_web/live/settings/ --max-failures 5`
Expected: Existing tests still pass. New fields render correctly.

**Step 3: Commit**

```bash
git add lib/klass_hero_web/live/settings/children_live.ex
git commit -m "feat: add gender and school grade fields to children settings (#151)"
```

---

## Task 8: Provider dashboard — participant restrictions form

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex` — add restrictions section to `program_form`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex` — handle participant_policy_form assign, validate, save

**Step 1: Add participant_policy_form assign to DashboardLive**

In `dashboard_live.ex`:
- In mount and reset assigns, add: `participant_policy_form: to_form(Enrollment.new_participant_policy_changeset(), as: "participant_policy")`
- In `handle_event("validate_program", ...)`: add validation of `participant_policy` params (same pattern as enrollment_form)
- In `handle_event("save_program", ...)`: after `maybe_set_enrollment_policy`, add `maybe_set_participant_policy(program.id, all_params["participant_policy"])`
- Add `maybe_set_participant_policy/2` private function (follow `maybe_set_enrollment_policy` pattern):
  - If all restriction fields are empty/nil → `:ok` (no policy needed)
  - Otherwise → call `Enrollment.set_participant_policy/1`
  - Parse age fields: UI sends year + month selects, convert to total months

**Step 2: Add restrictions section to program_form component**

In `provider_components.ex`, add `attr :participant_policy_form, :any, required: true` to `program_form`.

Add a new section after the Enrollment Capacity section (after line 888):

```heex
<%!-- Participant Restrictions Section --%>
<div class="space-y-3">
  <p class="text-sm font-semibold text-hero-charcoal">
    {gettext("Participant Restrictions (optional)")}
  </p>
  <p class="text-xs text-hero-grey-500">
    {gettext("Set age, gender, or grade requirements for eligible participants.")}
  </p>

  <%!-- Eligibility timing --%>
  <fieldset>
    <legend class="text-sm text-hero-grey-600 mb-2">{gettext("Check eligibility")}</legend>
    <div class="flex gap-4">
      <label class="inline-flex items-center gap-2 text-sm">
        <input type="radio" name="participant_policy[eligibility_at]" value="registration"
          checked={Phoenix.HTML.Form.input_value(@participant_policy_form, :eligibility_at) != "program_start"} />
        {gettext("At registration")}
      </label>
      <label class="inline-flex items-center gap-2 text-sm">
        <input type="radio" name="participant_policy[eligibility_at]" value="program_start"
          checked={Phoenix.HTML.Form.input_value(@participant_policy_form, :eligibility_at) == "program_start"} />
        {gettext("At program start")}
      </label>
    </div>
  </fieldset>

  <%!-- Age restriction --%>
  <div class="grid grid-cols-2 gap-4">
    <div>
      <label class="block text-sm text-hero-grey-600 mb-1">{gettext("Minimum Age")}</label>
      <div class="flex gap-2">
        <select name="participant_policy[min_age_years]" class="...">
          <option value="">{gettext("Years")}</option>
          <%= for y <- 0..18 do %>
            <option value={y}>{y}</option>
          <% end %>
        </select>
        <select name="participant_policy[min_age_months]" class="...">
          <option value="">{gettext("Months")}</option>
          <%= for m <- 0..11 do %>
            <option value={m}>{m}</option>
          <% end %>
        </select>
      </div>
    </div>
    <div>
      <label class="block text-sm text-hero-grey-600 mb-1">{gettext("Maximum Age")}</label>
      <%!-- same pattern as min --%>
    </div>
  </div>

  <%!-- Gender restriction (multi-select checkboxes) --%>
  <fieldset>
    <legend class="text-sm text-hero-grey-600 mb-2">{gettext("Allowed Genders")}</legend>
    <p class="text-xs text-hero-grey-400 mb-2">{gettext("Leave all unchecked for no restriction.")}</p>
    <div class="flex flex-wrap gap-3">
      <%= for {label, value} <- [{gettext("Male"), "male"}, {gettext("Female"), "female"}, {gettext("Diverse"), "diverse"}, {gettext("Not specified"), "not_specified"}] do %>
        <label class="inline-flex items-center gap-1.5 text-sm">
          <input type="checkbox" name="participant_policy[allowed_genders][]" value={value} />
          {label}
        </label>
      <% end %>
    </div>
    <input type="hidden" name="participant_policy[allowed_genders][]" value="" />
  </fieldset>

  <%!-- Grade restriction --%>
  <div class="grid grid-cols-2 gap-4">
    <.input
      field={@participant_policy_form[:min_grade]}
      type="select"
      label={gettext("Minimum Grade")}
      prompt={gettext("No minimum")}
      options={Enum.map(1..13, &{gettext("Klasse %{n}", n: &1), &1})}
    />
    <.input
      field={@participant_policy_form[:max_grade]}
      type="select"
      label={gettext("Maximum Grade")}
      prompt={gettext("No maximum")}
      options={Enum.map(1..13, &{gettext("Klasse %{n}", n: &1), &1})}
    />
  </div>
</div>
```

**Step 3: Pass participant_policy_form through to component**

In `programs_section/1` (line 987), add `participant_policy_form={@participant_policy_form}` to `<.program_form>`.

**Step 4: Add age parsing helper to DashboardLive**

```elixir
defp parse_age_to_months(params) do
  years = parse_integer(params["min_age_years"]) || 0
  months = parse_integer(params["min_age_months"]) || 0
  total = years * 12 + months
  if total == 0, do: nil, else: total
end
```

Similar for max.

**Step 5: Run all tests**

Run: `mix test --max-failures 5`
Expected: All pass (no test regressions).

**Step 6: Commit**

```bash
git add lib/klass_hero_web/components/provider_components.ex \
  lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "feat: add participant restrictions form to provider dashboard (#151)"
```

---

## Task 9: Booking LiveView — eligibility feedback

**Files:**
- Modify: `lib/klass_hero_web/live/booking_live.ex`
- Modify: `lib/klass_hero_web/components/booking_components.ex` (add eligibility status component)

**Step 1: Add eligibility check to BookingLive**

In `booking_live.ex`:
- Add `eligibility_status: nil` to mount assigns (nil = no child selected yet)
- In `handle_event("select_child", ...)` (line 100), after getting child, check eligibility:

```elixir
eligibility =
  case Enrollment.check_participant_eligibility(socket.assigns.program.id, child_id) do
    {:ok, :eligible} -> :eligible
    {:error, :ineligible, reasons} -> {:ineligible, reasons}
    _ -> :eligible  # fail open for display (server enforces on submit)
  end

{:noreply,
 assign(socket,
   selected_child_id: child_id,
   special_requirements: special_requirements,
   eligibility_status: eligibility
 )}
```

- In `handle_event("complete_enrollment", ...)`, add guard:

```elixir
# Check client-side eligibility state before submitting
case socket.assigns.eligibility_status do
  {:ineligible, _reasons} -> {:noreply, put_flash(socket, :error, gettext("Selected child does not meet the program requirements."))}
  _ -> # proceed with existing flow
end
```

- Handle `{:error, :ineligible, reasons}` in the `complete_enrollment` error handling.

**Step 2: Add eligibility_status component to BookingComponents**

```elixir
attr :status, :any, required: true  # nil | :eligible | {:ineligible, [String.t()]}

def eligibility_status(assigns) do
  ~H"""
  <div :if={@status == :eligible} class="flex items-center gap-2 p-3 bg-green-50 border border-green-200 rounded-lg mt-3">
    <.icon name="hero-check-circle-mini" class="w-5 h-5 text-green-600" />
    <span class="text-sm text-green-700">{gettext("Child meets all program requirements")}</span>
  </div>
  <div :if={match?({:ineligible, _}, @status)} class="p-3 bg-red-50 border border-red-200 rounded-lg mt-3">
    <div class="flex items-center gap-2 mb-2">
      <.icon name="hero-exclamation-triangle-mini" class="w-5 h-5 text-red-600" />
      <span class="text-sm font-semibold text-red-700">{gettext("Child does not meet program requirements")}</span>
    </div>
    <ul class="list-disc list-inside text-sm text-red-600 space-y-1">
      <li :for={reason <- elem(@status, 1)}>{reason}</li>
    </ul>
  </div>
  """
end
```

**Step 3: Add component to booking template**

After the child select dropdown (around line 401), add:

```heex
<.eligibility_status :if={@selected_child_id} status={@eligibility_status} />
```

Disable submit button when ineligible:

```heex
<button
  type="submit"
  disabled={match?({:ineligible, _}, @eligibility_status)}
  class={[
    "w-full py-4 text-white",
    # ... existing classes
    match?({:ineligible, _}, @eligibility_status) && "opacity-50 cursor-not-allowed"
  ]}
>
```

**Step 4: Run tests**

Run: `mix test --max-failures 5`
Expected: All pass.

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/booking_live.ex \
  lib/klass_hero_web/components/booking_components.ex
git commit -m "feat: show eligibility feedback in booking flow (#151)"
```

---

## Task 10: Program detail page — show restriction info

**Files:**
- Modify: Program detail LiveView (find exact path — likely `lib/klass_hero_web/live/program_detail_live.ex` or similar)
- Modify: `lib/klass_hero_web/components/program_components.ex` (add restrictions display component)

**Step 1: Add restriction info to program detail page**

Load participant policy in mount:

```elixir
participant_policy =
  case Enrollment.get_participant_policy(program.id) do
    {:ok, policy} -> policy
    {:error, :not_found} -> nil
  end

assign(socket, participant_policy: participant_policy)
```

**Step 2: Add display component**

A read-only card showing active restrictions:

```heex
<.restriction_info :if={@participant_policy} policy={@participant_policy} />
```

Component displays human-readable restrictions: "Ages 5-8 years", "Grades 3-6", "Female, Diverse", etc.

**Step 3: Run tests and commit**

Run: `mix test --max-failures 5`

```bash
git add lib/klass_hero_web/live/program_detail_live.ex \
  lib/klass_hero_web/components/program_components.ex
git commit -m "feat: display participant restrictions on program detail page (#151)"
```

---

## Task 11: Final integration testing and cleanup

**Files:**
- Run full test suite
- Run `mix precommit`

**Step 1: Run precommit**

Run: `mix precommit`
Expected: Compilation with --warnings-as-errors passes, format clean, all tests pass.

**Step 2: Fix any warnings or test failures**

Address any issues found.

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: cleanup warnings and fix test issues (#151)"
```
