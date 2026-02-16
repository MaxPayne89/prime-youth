# Registration Period Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add registration period (open/close dates) to programs so parents can only enroll during the configured window.

**Architecture:** RegistrationPeriod value object in Program Catalog domain. Flat DB columns mapped to/from VO at persistence boundary. Web layer gates booking and displays status.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL

---

### Task 1: RegistrationPeriod Value Object — Tests

**Files:**
- Create: `test/klass_hero/program_catalog/domain/models/registration_period_test.exs`

**Step 1: Write all RegistrationPeriod tests**

```elixir
defmodule KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriodTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriod

  describe "new/1" do
    test "creates with both dates" do
      assert {:ok, rp} = RegistrationPeriod.new(%{start_date: ~D[2026-03-01], end_date: ~D[2026-04-01]})
      assert rp.start_date == ~D[2026-03-01]
      assert rp.end_date == ~D[2026-04-01]
    end

    test "creates with only start_date" do
      assert {:ok, rp} = RegistrationPeriod.new(%{start_date: ~D[2026-03-01]})
      assert rp.start_date == ~D[2026-03-01]
      assert rp.end_date == nil
    end

    test "creates with only end_date" do
      assert {:ok, rp} = RegistrationPeriod.new(%{end_date: ~D[2026-04-01]})
      assert rp.start_date == nil
      assert rp.end_date == ~D[2026-04-01]
    end

    test "creates with both nil (always open)" do
      assert {:ok, rp} = RegistrationPeriod.new(%{})
      assert rp.start_date == nil
      assert rp.end_date == nil
    end

    test "rejects start_date after end_date" do
      assert {:error, errors} = RegistrationPeriod.new(%{start_date: ~D[2026-05-01], end_date: ~D[2026-03-01]})
      assert Enum.any?(errors, &String.contains?(&1, "before"))
    end

    test "rejects equal start_date and end_date" do
      assert {:error, errors} = RegistrationPeriod.new(%{start_date: ~D[2026-03-01], end_date: ~D[2026-03-01]})
      assert Enum.any?(errors, &String.contains?(&1, "before"))
    end
  end

  describe "status/1" do
    test "returns :always_open when both dates nil" do
      rp = %RegistrationPeriod{}
      assert RegistrationPeriod.status(rp) == :always_open
    end

    test "returns :upcoming when today is before start_date" do
      future = Date.add(Date.utc_today(), 30)
      rp = %RegistrationPeriod{start_date: future, end_date: Date.add(future, 60)}
      assert RegistrationPeriod.status(rp) == :upcoming
    end

    test "returns :open when today is between start and end" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -5), end_date: Date.add(today, 5)}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :open on the exact start_date" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: today, end_date: Date.add(today, 10)}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :open on the exact end_date" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -10), end_date: today}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :closed when today is after end_date" do
      past = Date.add(Date.utc_today(), -30)
      rp = %RegistrationPeriod{start_date: Date.add(past, -60), end_date: past}
      assert RegistrationPeriod.status(rp) == :closed
    end

    test "returns :open when only start_date set and today is past it" do
      past = Date.add(Date.utc_today(), -5)
      rp = %RegistrationPeriod{start_date: past}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :upcoming when only start_date set and today is before it" do
      future = Date.add(Date.utc_today(), 5)
      rp = %RegistrationPeriod{start_date: future}
      assert RegistrationPeriod.status(rp) == :upcoming
    end

    test "returns :open when only end_date set and today is before it" do
      future = Date.add(Date.utc_today(), 5)
      rp = %RegistrationPeriod{end_date: future}
      assert RegistrationPeriod.status(rp) == :open
    end

    test "returns :closed when only end_date set and today is past it" do
      past = Date.add(Date.utc_today(), -5)
      rp = %RegistrationPeriod{end_date: past}
      assert RegistrationPeriod.status(rp) == :closed
    end
  end

  describe "open?/1" do
    test "true for always_open" do
      assert RegistrationPeriod.open?(%RegistrationPeriod{})
    end

    test "true for open" do
      today = Date.utc_today()
      rp = %RegistrationPeriod{start_date: Date.add(today, -5), end_date: Date.add(today, 5)}
      assert RegistrationPeriod.open?(rp)
    end

    test "false for upcoming" do
      future = Date.add(Date.utc_today(), 30)
      rp = %RegistrationPeriod{start_date: future}
      refute RegistrationPeriod.open?(rp)
    end

    test "false for closed" do
      past = Date.add(Date.utc_today(), -30)
      rp = %RegistrationPeriod{end_date: past}
      refute RegistrationPeriod.open?(rp)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/program_catalog/domain/models/registration_period_test.exs`
Expected: Compilation error — module not found

**Step 3: Commit test file**

```bash
git add test/klass_hero/program_catalog/domain/models/registration_period_test.exs
git commit -m "test: add RegistrationPeriod value object tests (#147)"
```

---

### Task 2: RegistrationPeriod Value Object — Implementation

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/models/registration_period.ex`

**Step 1: Implement RegistrationPeriod**

```elixir
defmodule KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriod do
  @moduledoc """
  Value object representing a program's registration window.

  Encapsulates the start and end dates during which parents may enroll.
  Both dates are optional — when both are nil, registration is always open.
  """

  defstruct [:start_date, :end_date]

  @type t :: %__MODULE__{
          start_date: Date.t() | nil,
          end_date: Date.t() | nil
        }

  @type status :: :always_open | :upcoming | :open | :closed

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    start_date = attrs[:start_date]
    end_date = attrs[:end_date]

    errors = validate_date_ordering(start_date, end_date)

    if errors == [] do
      {:ok, %__MODULE__{start_date: start_date, end_date: end_date}}
    else
      {:error, errors}
    end
  end

  @spec status(t()) :: status()
  def status(%__MODULE__{start_date: nil, end_date: nil}), do: :always_open

  def status(%__MODULE__{start_date: start_date, end_date: nil}) do
    # Trigger: only start_date is set
    # Why: no end date means registration stays open once it starts
    # Outcome: :upcoming if before start, :open if on or after start
    if Date.before?(Date.utc_today(), start_date), do: :upcoming, else: :open
  end

  def status(%__MODULE__{start_date: nil, end_date: end_date}) do
    # Trigger: only end_date is set
    # Why: no start date means registration was open from the beginning
    # Outcome: :open if on or before end, :closed if after end
    if Date.after?(Date.utc_today(), end_date), do: :closed, else: :open
  end

  def status(%__MODULE__{start_date: start_date, end_date: end_date}) do
    today = Date.utc_today()

    # Trigger: both dates are set
    # Why: defines a closed window [start, end] inclusive on both sides
    # Outcome: :upcoming before start, :open within range, :closed after end
    cond do
      Date.before?(today, start_date) -> :upcoming
      Date.after?(today, end_date) -> :closed
      true -> :open
    end
  end

  @spec open?(t()) :: boolean()
  def open?(%__MODULE__{} = rp), do: status(rp) in [:always_open, :open]

  defp validate_date_ordering(nil, _), do: []
  defp validate_date_ordering(_, nil), do: []

  defp validate_date_ordering(%Date{} = start_date, %Date{} = end_date) do
    if Date.before?(start_date, end_date) do
      []
    else
      ["registration_start_date must be before registration_end_date"]
    end
  end
end
```

**Step 2: Run tests to verify they pass**

Run: `mix test test/klass_hero/program_catalog/domain/models/registration_period_test.exs`
Expected: All tests pass

**Step 3: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/registration_period.ex
git commit -m "feat: add RegistrationPeriod value object (#147)"
```

---

### Task 3: Add RegistrationPeriod to Program Domain Model

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`
- Modify: `test/klass_hero/program_catalog/domain/models/program_test.exs`

**Step 1: Add tests for registration_period on Program**

Add to `program_test.exs`:

- In `valid_attrs/1`: add `registration_period: %RegistrationPeriod{}` default
- Test `create/1` builds RegistrationPeriod from flat attrs (`registration_start_date`, `registration_end_date`)
- Test `create/1` defaults to empty RegistrationPeriod when no registration dates provided
- Test `apply_changes/2` updates registration_period field
- Test `create/1` rejects invalid registration period (start after end)

**Step 2: Implement changes on Program**

In `program.ex`:
- `alias RegistrationPeriod`
- Add `registration_period` to `defstruct` with default `%RegistrationPeriod{}`
- Add `registration_period: RegistrationPeriod.t()` to `@type t`
- In `build_base/2`: build RegistrationPeriod from `attrs[:registration_start_date]` and `attrs[:registration_end_date]`
- Add `:registration_period` to `@updatable_fields`
- In `validate_creation_invariants/1`: call `validate_registration_period/1`
- `validate_registration_period` delegates to `RegistrationPeriod.new/1` and collects errors

**Step 3: Run tests**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: All pass

**Step 4: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex test/klass_hero/program_catalog/domain/models/program_test.exs
git commit -m "feat: add registration_period to Program domain model (#147)"
```

---

### Task 4: Database Migration + ProgramSchema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_registration_period_to_programs.exs`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`
- Modify: `test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs`

**Step 1: Generate migration**

Run: `mix ecto.gen.migration add_registration_period_to_programs`

**Step 2: Write migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddRegistrationPeriodToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :registration_start_date, :date
      add :registration_end_date, :date
    end
  end
end
```

**Step 3: Add fields to ProgramSchema**

In `program_schema.ex`:
- Add `field :registration_start_date, :date` and `field :registration_end_date, :date` to schema
- Add both to `@type t`
- Add both to `cast` lists in `changeset/2`, `create_changeset/2`, `update_changeset/2`
- Add `validate_registration_date_range/1` (same pattern as `validate_date_range/1`)
- Pipe `validate_registration_date_range()` in all three changeset functions

**Step 4: Add schema tests**

Add to `program_schema_test.exs`:
- Test valid registration dates accepted in create_changeset
- Test valid registration dates accepted in update_changeset
- Test rejects registration_start_date on or after registration_end_date
- Test allows registration_start_date without registration_end_date
- Test allows registration_end_date without registration_start_date

**Step 5: Run migration and tests**

Run: `mix ecto.migrate && mix test test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs`
Expected: Migration succeeds, all tests pass

**Step 6: Commit**

```bash
git add priv/repo/migrations/*_add_registration_period_to_programs.exs lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs
git commit -m "feat: add registration period fields to programs schema (#147)"
```

---

### Task 5: ProgramMapper — VO Assembly/Disassembly

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`
- Modify: `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`

**Step 1: Add mapper tests**

Add to `program_mapper_test.exs`:

```elixir
# In "to_domain/1" describe block:
test "assembles RegistrationPeriod from flat schema columns" do
  schema = %ProgramSchema{
    id: Ecto.UUID.generate(),
    title: "Test", description: "Desc", age_range: "6-12",
    price: Decimal.new("100.00"), pricing_period: "per week",
    spots_available: 10,
    registration_start_date: ~D[2026-03-01],
    registration_end_date: ~D[2026-04-01],
    inserted_at: ~U[2024-01-01 10:00:00Z],
    updated_at: ~U[2024-01-01 10:00:00Z]
  }

  domain = ProgramMapper.to_domain(schema)

  assert %RegistrationPeriod{} = domain.registration_period
  assert domain.registration_period.start_date == ~D[2026-03-01]
  assert domain.registration_period.end_date == ~D[2026-04-01]
end

test "assembles empty RegistrationPeriod when dates are nil" do
  schema = %ProgramSchema{
    id: Ecto.UUID.generate(),
    title: "Test", description: "Desc", age_range: "6-12",
    price: Decimal.new("100.00"), pricing_period: "per week",
    spots_available: 10,
    inserted_at: ~U[2024-01-01 10:00:00Z],
    updated_at: ~U[2024-01-01 10:00:00Z]
  }

  domain = ProgramMapper.to_domain(schema)

  assert %RegistrationPeriod{start_date: nil, end_date: nil} = domain.registration_period
end

# In "to_schema/1" describe block:
test "destructures RegistrationPeriod to flat columns" do
  rp = %RegistrationPeriod{start_date: ~D[2026-03-01], end_date: ~D[2026-04-01]}
  program = %Program{
    id: "abc", title: "Test", description: "Desc", category: "arts",
    price: Decimal.new("50.00"), provider_id: "xyz", spots_available: 10,
    registration_period: rp
  }

  attrs = ProgramMapper.to_schema(program)
  assert attrs.registration_start_date == ~D[2026-03-01]
  assert attrs.registration_end_date == ~D[2026-04-01]
end

test "destructures nil RegistrationPeriod to nil columns" do
  program = %Program{
    id: "abc", title: "Test", description: "Desc", category: "arts",
    price: Decimal.new("50.00"), provider_id: "xyz", spots_available: 10,
    registration_period: %RegistrationPeriod{}
  }

  attrs = ProgramMapper.to_schema(program)
  assert attrs.registration_start_date == nil
  assert attrs.registration_end_date == nil
end
```

**Step 2: Implement mapper changes**

In `program_mapper.ex`:
- `alias RegistrationPeriod`
- In `to_domain/1`: add `registration_period: build_registration_period(schema)`
- Add `defp build_registration_period(schema)` that creates `%RegistrationPeriod{start_date: schema.registration_start_date, end_date: schema.registration_end_date}`
- In `to_schema/1`: add `registration_start_date: program.registration_period.start_date` and `registration_end_date: program.registration_period.end_date` to the base map (handle nil registration_period defensively)

**Step 3: Run tests**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`
Expected: All pass

**Step 4: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs
git commit -m "feat: map registration period between domain and schema (#147)"
```

---

### Task 6: Provider Form — Registration Date Inputs

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex` (program_form)
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex` (save_program handler)

**Step 1: Add date inputs to program_form template**

In `provider_components.ex`, inside `program_form/1`, after the Schedule section's date inputs (after line ~841), add:

```heex
<%!-- Registration Period Section --%>
<div class="space-y-3">
  <p class="text-sm font-semibold text-hero-charcoal">{gettext("Registration Period (optional)")}</p>
  <p class="text-xs text-hero-grey-500">
    {gettext("Leave blank for open registration at any time.")}
  </p>
  <div class="grid grid-cols-2 gap-4">
    <.input
      field={@form[:registration_start_date]}
      type="date"
      label={gettext("Registration Opens")}
    />
    <.input
      field={@form[:registration_end_date]}
      type="date"
      label={gettext("Registration Closes")}
    />
  </div>
</div>
```

**Step 2: Add parsing in save_program handler**

In `dashboard_live.ex`, in the `handle_event("save_program", ...)` attrs map, add:

```elixir
registration_start_date: parse_date(params["registration_start_date"]),
registration_end_date: parse_date(params["registration_end_date"])
```

The `parse_date/1` helper already exists in the module.

**Step 3: Run precommit**

Run: `mix precommit`
Expected: Compiles without warnings, tests pass

**Step 4: Commit**

```bash
git add lib/klass_hero_web/components/provider_components.ex lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "feat: add registration period inputs to provider program form (#147)"
```

---

### Task 7: ProgramDetailLive — Registration Status Display

**Files:**
- Modify: `lib/klass_hero_web/live/program_detail_live.ex`

**Step 1: Add registration_status assign in mount**

In `mount/3`, after `assign(program: program_with_items)`, add:

```elixir
|> assign(registration_status: RegistrationPeriod.status(program.registration_period))
```

Add alias: `alias KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriod`

**Step 2: Add status banner in template**

In `render/1`, insert a registration status banner between the hero section and the pricing card (before line ~191 `<%!-- Pricing Card -->`):

```heex
<%!-- Registration Status Banner --%>
<div
  :if={@registration_status in [:upcoming, :closed]}
  class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 -mt-3 relative z-10 mb-3"
>
  <.info_box
    variant={if(@registration_status == :upcoming, do: :info, else: :neutral)}
    icon={if(@registration_status == :upcoming, do: "📅", else: "🔒")}
    title={registration_status_title(@registration_status, @program.registration_period)}
  />
</div>
```

**Step 3: Add helper function for status title**

```elixir
defp registration_status_title(:upcoming, %RegistrationPeriod{start_date: start_date}) do
  gettext("Registration opens %{date}", date: Calendar.strftime(start_date, "%B %d, %Y"))
end

defp registration_status_title(:closed, _rp) do
  gettext("Registration is closed")
end
```

**Step 4: Conditionally disable Book Now buttons**

Modify the three "Book Now" / "Enroll Now" buttons (hero pricing card, desktop CTA, mobile sticky):

- Wrap each `phx-click="enroll_now"` to only fire when open:
  - Add `disabled={@registration_status in [:upcoming, :closed]}`
  - Conditionally change class to muted styling when disabled
  - Change button text when not open

**Step 5: Modify enroll_now event handler**

Add guard clause:

```elixir
def handle_event("enroll_now", _params, socket) do
  if RegistrationPeriod.open?(socket.assigns.program.registration_period) do
    {:noreply, push_navigate(socket, to: ~p"/programs/#{socket.assigns.program.id}/booking")}
  else
    {:noreply, put_flash(socket, :error, gettext("Registration is not open for this program."))}
  end
end
```

**Step 6: Run precommit**

Run: `mix precommit`
Expected: All pass

**Step 7: Commit**

```bash
git add lib/klass_hero_web/live/program_detail_live.ex
git commit -m "feat: show registration status on program detail page (#147)"
```

---

### Task 8: BookingLive — Registration Gate

**Files:**
- Modify: `lib/klass_hero_web/live/booking_live.ex`

**Step 1: Add registration check in mount**

In `mount/3`, modify the `with` chain:

```elixir
with {:ok, program} <- fetch_program(program_id),
     :ok <- validate_registration_open(program),
     :ok <- validate_program_availability(program) do
```

Add the new validation function:

```elixir
defp validate_registration_open(program) do
  alias KlassHero.ProgramCatalog.Domain.Models.RegistrationPeriod

  if RegistrationPeriod.open?(program.registration_period) do
    :ok
  else
    {:error, :registration_not_open}
  end
end
```

**Step 2: Add error handling clause**

In the `else` block, add before the catch-all:

```elixir
{:error, :registration_not_open} ->
  program_for_redirect = fetch_program_unsafe(program_id)

  {:ok,
   socket
   |> put_flash(:error, gettext("Registration is not currently open for this program."))
   |> redirect(to: ~p"/programs/#{program_for_redirect.id}")}
```

**Step 3: Add registration check in complete_enrollment**

In `handle_event("complete_enrollment", ...)`, add to the `with` chain:

```elixir
with :ok <- validate_enrollment_data(socket, params),
     :ok <- validate_payment_method(socket),
     :ok <- validate_registration_open(socket.assigns.program),
     :ok <- validate_program_availability(socket.assigns.program),
     {:ok, _enrollment} <- create_enrollment(socket, params) do
```

Add matching error clause:

```elixir
{:error, :registration_not_open} ->
  {:noreply,
   socket
   |> put_flash(:error, gettext("Registration has closed for this program."))
   |> push_navigate(to: ~p"/programs/#{socket.assigns.program.id}")}
```

**Step 4: Run precommit**

Run: `mix precommit`
Expected: All pass

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/booking_live.ex
git commit -m "feat: gate booking flow on registration period (#147)"
```

---

### Task 9: Full Integration Test Run + Cleanup

**Files:**
- All modified files

**Step 1: Run full test suite**

Run: `mix precommit`
Expected: Zero warnings, all tests pass

**Step 2: Verify existing integration tests still pass**

Run: `mix test test/klass_hero/program_catalog/create_program_integration_test.exs test/klass_hero/program_catalog/update_program_integration_test.exs`
Expected: All pass (these exercise the full create/update pipeline including mapper)

**Step 3: Final commit if any fixups needed**

Only if fixes were required in the previous steps.
