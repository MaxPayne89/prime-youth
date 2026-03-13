# Admin Sessions Dashboard Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add participation session management to the admin dashboard with today/filter dual-mode, roster display, and inline attendance corrections.

**Architecture:** Custom LiveView rendering inside the Backpex admin shell (not a Backpex resource). New `admin_correct/2` domain method on `ParticipationRecord` allows any-direction status transitions. `ListSessions` extended with joins for program/provider names and attendance counts. `CorrectAttendance` use case orchestrates corrections with required reasons appended to notes fields.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL, Tailwind CSS, ExMachina (tests)

**Spec:** `docs/superpowers/specs/2026-03-13-admin-sessions-design.md`

**Skills:** @superpowers:test-driven-development, @idiomatic-elixir

---

## Chunk 1: Domain Layer — `admin_correct/2` and `CorrectAttendance` Use Case

### Task 1: Add `admin_correct/2` to ParticipationRecord Domain Model

**Files:**
- Modify: `lib/klass_hero/participation/domain/models/participation_record.ex`
- Test: `test/klass_hero/participation/domain/models/participation_record_test.exs`

**Context:** The existing state machine only allows forward transitions (`registered → checked_in → checked_out`, `registered → absent`). Admin corrections need any-direction transitions between valid statuses. This is a pure domain function — no DB, no IO.

- [ ] **Step 1: Write failing tests for `admin_correct/2`**

Create or extend the test file. Tests cover: valid transitions in all directions, time updates, logical consistency (no `check_out_at` without `check_in_at`), and rejection of no-change corrections.

```elixir
# test/klass_hero/participation/domain/models/participation_record_test.exs

defmodule KlassHero.Participation.Domain.Models.ParticipationRecordTest do
  use ExUnit.Case, async: true

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  describe "admin_correct/2" do
    setup do
      {:ok, record} =
        ParticipationRecord.new(%{
          id: "rec-1",
          session_id: "sess-1",
          child_id: "child-1"
        })

      %{record: record}
    end

    test "corrects registered → checked_in with check_in_at", %{record: record} do
      check_in_at = ~U[2026-03-13 09:00:00Z]

      assert {:ok, corrected} =
               ParticipationRecord.admin_correct(record, %{
                 status: :checked_in,
                 check_in_at: check_in_at
               })

      assert corrected.status == :checked_in
      assert corrected.check_in_at == check_in_at
    end

    test "corrects absent → checked_in (reverse transition)", %{record: record} do
      {:ok, absent} = ParticipationRecord.mark_absent(record)
      check_in_at = ~U[2026-03-13 09:05:00Z]

      assert {:ok, corrected} =
               ParticipationRecord.admin_correct(absent, %{
                 status: :checked_in,
                 check_in_at: check_in_at
               })

      assert corrected.status == :checked_in
    end

    test "corrects checked_out → checked_in (reverse transition)" do
      record = build_checked_out_record()

      assert {:ok, corrected} =
               ParticipationRecord.admin_correct(record, %{status: :checked_in})

      assert corrected.status == :checked_in
      assert corrected.check_out_at == nil
      assert corrected.check_out_by == nil
      assert corrected.check_out_notes == nil
    end

    test "corrects check_in_at time only (no status change)" do
      record = build_checked_in_record()
      new_time = ~U[2026-03-13 09:15:00Z]

      assert {:ok, corrected} =
               ParticipationRecord.admin_correct(record, %{check_in_at: new_time})

      assert corrected.check_in_at == new_time
      assert corrected.status == :checked_in
    end

    test "corrects check_out_at time only (no status change)" do
      record = build_checked_out_record()
      new_time = ~U[2026-03-13 11:30:00Z]

      assert {:ok, corrected} =
               ParticipationRecord.admin_correct(record, %{check_out_at: new_time})

      assert corrected.check_out_at == new_time
    end

    test "rejects check_out_at without check_in_at present" do
      {:ok, record} =
        ParticipationRecord.new(%{id: "r-1", session_id: "s-1", child_id: "c-1"})

      assert {:error, :check_out_requires_check_in} =
               ParticipationRecord.admin_correct(record, %{
                 status: :checked_out,
                 check_out_at: ~U[2026-03-13 10:00:00Z]
               })
    end

    test "rejects empty corrections (no changes)", %{record: record} do
      assert {:error, :no_changes} =
               ParticipationRecord.admin_correct(record, %{})
    end

    test "rejects invalid status atom", %{record: record} do
      assert {:error, :invalid_status} =
               ParticipationRecord.admin_correct(record, %{status: :invalid})
    end

    # -- helpers --

    defp build_checked_in_record do
      {:ok, record} =
        ParticipationRecord.new(%{id: "r-ci", session_id: "s-1", child_id: "c-1"})

      {:ok, checked_in} = ParticipationRecord.check_in(record, "provider-1", "On time")
      checked_in
    end

    defp build_checked_out_record do
      checked_in = build_checked_in_record()
      {:ok, checked_out} = ParticipationRecord.check_out(checked_in, "provider-1")
      checked_out
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/domain/models/participation_record_test.exs -v`
Expected: FAIL — `admin_correct/2` is undefined

- [ ] **Step 3: Implement `admin_correct/2`**

Add to `lib/klass_hero/participation/domain/models/participation_record.ex`:

```elixir
@valid_statuses [:registered, :checked_in, :checked_out, :absent]

@doc """
Admin correction — allows any status transition and time edits.

Unlike `check_in/3` and `check_out/3`, this bypasses the forward-only
state machine for administrative fixes.

## Validations
- At least one field must change (status or times)
- `check_out_at` requires `check_in_at` to be present (on the record or in attrs)
- Status must be a valid status atom
"""
@spec admin_correct(t(), map()) :: {:ok, t()} | {:error, atom()}
def admin_correct(%__MODULE__{} = record, attrs) when is_map(attrs) do
  with :ok <- validate_has_changes(record, attrs),
       :ok <- validate_status(attrs),
       :ok <- validate_check_out_consistency(record, attrs) do
    corrected = apply_corrections(record, attrs)
    {:ok, corrected}
  end
end

defp validate_has_changes(record, attrs) do
  has_status_change = Map.has_key?(attrs, :status) and attrs.status != record.status
  has_time_change =
    (Map.has_key?(attrs, :check_in_at) and attrs.check_in_at != record.check_in_at) or
    (Map.has_key?(attrs, :check_out_at) and attrs.check_out_at != record.check_out_at)

  if has_status_change or has_time_change, do: :ok, else: {:error, :no_changes}
end

defp validate_status(%{status: status}) when status not in @valid_statuses,
  do: {:error, :invalid_status}
defp validate_status(_attrs), do: :ok

defp validate_check_out_consistency(record, attrs) do
  new_status = Map.get(attrs, :status, record.status)
  has_check_in = record.check_in_at != nil or Map.has_key?(attrs, :check_in_at)

  # Trigger: transitioning to checked_out or setting check_out_at
  # Why: a child can't be checked out without first being checked in
  # Outcome: rejects logically impossible corrections
  if new_status == :checked_out and not has_check_in do
    {:error, :check_out_requires_check_in}
  else
    :ok
  end
end

defp apply_corrections(record, attrs) do
  record
  |> maybe_update(:status, attrs)
  |> maybe_update(:check_in_at, attrs)
  |> maybe_update(:check_out_at, attrs)
  |> clear_downstream_fields(attrs)
end

defp maybe_update(record, field, attrs) do
  case Map.fetch(attrs, field) do
    {:ok, value} -> Map.put(record, field, value)
    :error -> record
  end
end

# Trigger: status corrected backwards (e.g. checked_out → checked_in)
# Why: downstream fields from a reversed state are no longer valid
# Outcome: clears check-out data when reverting from checked_out
defp clear_downstream_fields(record, %{status: :checked_in}) do
  %{record | check_out_at: nil, check_out_by: nil, check_out_notes: nil}
end

defp clear_downstream_fields(record, %{status: :registered}) do
  %{record | check_in_at: nil, check_in_by: nil, check_in_notes: nil,
             check_out_at: nil, check_out_by: nil, check_out_notes: nil}
end

defp clear_downstream_fields(record, %{status: :absent}) do
  %{record | check_in_at: nil, check_in_by: nil, check_in_notes: nil,
             check_out_at: nil, check_out_by: nil, check_out_notes: nil}
end

defp clear_downstream_fields(record, _attrs), do: record
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/domain/models/participation_record_test.exs -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/participation/domain/models/participation_record.ex \
        test/klass_hero/participation/domain/models/participation_record_test.exs
git commit -m "feat: add admin_correct/2 to ParticipationRecord for admin corrections"
```

---

### Task 2: Create `CorrectAttendance` Use Case

**Files:**
- Create: `lib/klass_hero/participation/application/use_cases/correct_attendance.ex`
- Test: `test/klass_hero/participation/application/use_cases/correct_attendance_test.exs`
- Modify: `lib/klass_hero/participation.ex` (expose public API)

**Context:** Orchestrates admin corrections: fetches record, delegates to `admin_correct/2`, appends reason to notes, persists. Uses the existing `ForManagingParticipation` port for persistence. Follow the `RecordCheckIn` use case pattern.

- [ ] **Step 1: Write failing tests for `CorrectAttendance.execute/1`**

```elixir
# test/klass_hero/participation/application/use_cases/correct_attendance_test.exs

defmodule KlassHero.Participation.Application.UseCases.CorrectAttendanceTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation

  describe "correct_attendance/1" do
    setup do
      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()
      provider = insert(:provider_profile_schema)
      session = insert(:program_session_schema, status: "in_progress")

      {child, parent} = insert_child_with_guardian()

      record =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: parent.id,
          status: :checked_in,
          check_in_at: ~U[2026-03-13 09:00:00Z],
          check_in_by: user.id
        )

      %{record: record, session: session}
    end

    test "corrects status with required reason", %{record: record} do
      assert {:ok, corrected} =
               Participation.correct_attendance(%{
                 record_id: record.id,
                 status: :checked_out,
                 check_out_at: ~U[2026-03-13 10:30:00Z],
                 reason: "Provider forgot to check out"
               })

      assert corrected.status == :checked_out
      assert corrected.check_out_at == ~U[2026-03-13 10:30:00Z]
      assert corrected.check_out_notes =~ "[Admin correction]"
      assert corrected.check_out_notes =~ "Provider forgot to check out"
    end

    test "corrects check_in_at time with reason appended to existing notes", %{record: record} do
      new_time = ~U[2026-03-13 09:15:00Z]

      assert {:ok, corrected} =
               Participation.correct_attendance(%{
                 record_id: record.id,
                 check_in_at: new_time,
                 reason: "Wrong check-in time recorded"
               })

      assert corrected.check_in_at == new_time
      assert corrected.check_in_notes =~ "[Admin correction]"
    end

    test "rejects correction without reason", %{record: record} do
      assert {:error, :reason_required} =
               Participation.correct_attendance(%{
                 record_id: record.id,
                 status: :checked_out,
                 check_out_at: ~U[2026-03-13 10:30:00Z]
               })
    end

    test "rejects correction with blank reason", %{record: record} do
      assert {:error, :reason_required} =
               Participation.correct_attendance(%{
                 record_id: record.id,
                 status: :absent,
                 reason: "   "
               })
    end

    test "rejects correction with no changes", %{record: record} do
      assert {:error, :no_changes} =
               Participation.correct_attendance(%{
                 record_id: record.id,
                 reason: "Testing"
               })
    end

    test "returns not_found for invalid record_id" do
      assert {:error, :not_found} =
               Participation.correct_attendance(%{
                 record_id: Ecto.UUID.generate(),
                 status: :absent,
                 reason: "Mistake"
               })
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/application/use_cases/correct_attendance_test.exs -v`
Expected: FAIL — `correct_attendance/1` is undefined on `Participation`

- [ ] **Step 3: Implement `CorrectAttendance` use case**

```elixir
# lib/klass_hero/participation/application/use_cases/correct_attendance.ex

defmodule KlassHero.Participation.Application.UseCases.CorrectAttendance do
  @moduledoc """
  Use case for admin corrections to attendance records.

  Allows admins to change status and/or check-in/check-out times on a
  participation record. Requires a reason that is appended (not replaced)
  to the appropriate notes field.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @participation_repository Application.compile_env!(
                              :klass_hero,
                              [:participation, :participation_repository]
                            )

  @type params :: %{
          required(:record_id) => String.t(),
          required(:reason) => String.t(),
          optional(:status) => ParticipationRecord.status(),
          optional(:check_in_at) => DateTime.t(),
          optional(:check_out_at) => DateTime.t()
        }

  @type result :: {:ok, ParticipationRecord.t()} | {:error, atom()}

  @doc """
  Corrects a participation record's attendance data.

  ## Parameters
  - `record_id` — ID of the participation record to correct
  - `reason` — required explanation for the correction
  - `status` — optional new status
  - `check_in_at` — optional corrected check-in time
  - `check_out_at` — optional corrected check-out time
  """
  @spec execute(params()) :: result()
  def execute(%{record_id: record_id, reason: reason} = params) do
    with :ok <- validate_reason(reason),
         correction_attrs <- build_correction_attrs(params),
         {:ok, record} <- @participation_repository.get_by_id(record_id),
         {:ok, corrected} <- ParticipationRecord.admin_correct(record, correction_attrs),
         corrected_with_notes <- append_correction_reason(corrected, record, params),
         {:ok, persisted} <- @participation_repository.update(corrected_with_notes) do
      {:ok, persisted}
    end
  end

  def execute(%{record_id: _record_id}), do: {:error, :reason_required}

  defp validate_reason(reason) when is_binary(reason) do
    if String.trim(reason) == "", do: {:error, :reason_required}, else: :ok
  end

  defp validate_reason(_), do: {:error, :reason_required}

  defp build_correction_attrs(params) do
    params
    |> Map.take([:status, :check_in_at, :check_out_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Trigger: check_in_at was changed
  # Why: correction reason belongs alongside the data that was corrected
  # Outcome: reason appended to check_in_notes
  defp append_correction_reason(corrected, original, %{reason: reason} = params) do
    note = "[Admin correction] #{String.trim(reason)}"

    cond do
      Map.has_key?(params, :check_in_at) and params.check_in_at != original.check_in_at ->
        append_to_field(corrected, :check_in_notes, note)

      Map.has_key?(params, :check_out_at) and params.check_out_at != original.check_out_at ->
        append_to_field(corrected, :check_out_notes, note)

      Map.has_key?(params, :status) and params.status != original.status ->
        append_to_field(corrected, :check_in_notes, note)

      true ->
        corrected
    end
  end

  defp append_to_field(record, field, note) do
    existing = Map.get(record, field)

    new_value =
      case existing do
        nil -> note
        "" -> note
        existing -> "#{existing} | #{note}"
      end

    Map.put(record, field, new_value)
  end
end
```

- [ ] **Step 4: Expose in context facade**

Add to `lib/klass_hero/participation.ex`:

```elixir
alias KlassHero.Participation.Application.UseCases.CorrectAttendance

@doc "Admin-corrects a participation record's attendance data."
def correct_attendance(params) when is_map(params) do
  CorrectAttendance.execute(params)
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/application/use_cases/correct_attendance_test.exs -v`
Expected: ALL PASS

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: ALL PASS (no regressions)

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/application/use_cases/correct_attendance.ex \
        lib/klass_hero/participation.ex \
        test/klass_hero/participation/application/use_cases/correct_attendance_test.exs
git commit -m "feat: add CorrectAttendance use case for admin attendance fixes"
```

---

## Chunk 2: Extended `ListSessions` with Enrichment

### Task 3: Extend `ForManagingSessions` Port and `SessionRepository`

**Files:**
- Modify: `lib/klass_hero/participation/domain/ports/for_managing_sessions.ex`
- Modify: `lib/klass_hero/participation/adapters/driven/persistence/repositories/session_repository.ex`
- Test: `test/klass_hero/participation/adapters/driven/persistence/repositories/session_repository_test.exs`

**Context:** The index page needs sessions with program name, provider name, and attendance counts. This requires a new query that joins `programs` and `providers` tables and aggregates `participation_records`. Add a `list_admin_sessions/1` callback to the port, keeping the existing `list_today_sessions` and `list_by_program` untouched.

- [ ] **Step 1: Write failing tests for `list_admin_sessions/1`**

```elixir
# test/klass_hero/participation/adapters/driven/persistence/repositories/session_repository_test.exs
# (add new describe block to existing file, or create if needed)

describe "list_admin_sessions/1" do
  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    today = Date.utc_today()

    session =
      insert(:program_session_schema,
        program_id: program.id,
        session_date: today,
        status: "in_progress"
      )

    {child, parent} = insert_child_with_guardian()
    user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()

    insert(:participation_record_schema,
      session_id: session.id,
      child_id: child.id,
      parent_id: parent.id,
      status: :checked_in,
      check_in_at: DateTime.utc_now(),
      check_in_by: user.id
    )

    %{provider: provider, program: program, session: session, today: today}
  end

  test "returns sessions for today with enriched data", %{today: today, program: program} do
    results = SessionRepository.list_admin_sessions(%{date: today})

    assert [session_map] = results
    assert session_map.program_name == program.title
    assert is_binary(session_map.provider_name)
    assert session_map.checked_in_count == 1
    assert session_map.total_count == 1
  end

  test "filters by provider_id", %{provider: provider, today: today} do
    # Create another provider's session
    other_provider = insert(:provider_profile_schema)
    other_program = insert(:program_schema, provider_id: other_provider.id)
    insert(:program_session_schema, program_id: other_program.id, session_date: today)

    results = SessionRepository.list_admin_sessions(%{date: today, provider_id: provider.id})
    assert length(results) == 1
  end

  test "filters by status", %{today: today} do
    results = SessionRepository.list_admin_sessions(%{date: today, status: :in_progress})
    assert length(results) == 1

    results = SessionRepository.list_admin_sessions(%{date: today, status: :completed})
    assert results == []
  end

  test "filters by date range" do
    yesterday = Date.add(Date.utc_today(), -1)
    tomorrow = Date.add(Date.utc_today(), 1)

    results =
      SessionRepository.list_admin_sessions(%{
        date_from: yesterday,
        date_to: tomorrow
      })

    assert length(results) == 1
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/adapters/driven/persistence/repositories/session_repository_test.exs --only describe:"list_admin_sessions/1" -v`
Expected: FAIL — `list_admin_sessions/1` is undefined

- [ ] **Step 3: Add callback to port**

Add to `lib/klass_hero/participation/domain/ports/for_managing_sessions.ex`:

```elixir
@type admin_filter :: %{
        optional(:date) => Date.t(),
        optional(:date_from) => Date.t(),
        optional(:date_to) => Date.t(),
        optional(:provider_id) => String.t(),
        optional(:program_id) => String.t(),
        optional(:status) => atom()
      }

@type admin_session :: %{
        id: String.t(),
        program_id: String.t(),
        program_name: String.t(),
        provider_name: String.t(),
        session_date: Date.t(),
        start_time: Time.t(),
        end_time: Time.t(),
        status: atom(),
        checked_in_count: non_neg_integer(),
        total_count: non_neg_integer()
      }

@doc "Lists sessions with enriched data for admin dashboard."
@callback list_admin_sessions(admin_filter()) :: [admin_session()]
```

- [ ] **Step 4: Implement in `SessionRepository`**

Add to `lib/klass_hero/participation/adapters/driven/persistence/repositories/session_repository.ex`:

```elixir
@impl true
def list_admin_sessions(filters) when is_map(filters) do
  ProgramSessionSchema
  |> join(:inner, [s], p in ProgramSchema, on: p.id == s.program_id)
  |> join(:left, [s, _p], pr in ParticipationRecordSchema, on: pr.session_id == s.id)
  |> join(:inner, [_s, p, _pr], prov in ProviderProfileSchema, on: prov.id == p.provider_id)
  |> apply_admin_filters(filters)
  |> group_by([s, p, _pr, prov], [s.id, p.title, prov.business_name])
  |> select([s, p, _pr, prov], %{
    id: s.id,
    program_id: s.program_id,
    program_name: p.title,
    provider_name: prov.business_name,
    session_date: s.session_date,
    start_time: s.start_time,
    end_time: s.end_time,
    status: s.status,
    checked_in_count:
      count(
        fragment(
          "CASE WHEN ? IN ('checked_in', 'checked_out') THEN 1 END",
          _pr.status
        )
      ),
    total_count: count(_pr.id)
  })
  |> order_by([s, _p, _pr, _prov], asc: s.session_date, asc: s.start_time)
  |> Repo.all()
  |> Enum.map(&atomize_status/1)
end

defp apply_admin_filters(query, filters) do
  query
  |> maybe_filter_date(filters)
  |> maybe_filter_date_range(filters)
  |> maybe_filter_provider(filters)
  |> maybe_filter_program(filters)
  |> maybe_filter_status(filters)
end

defp maybe_filter_date(query, %{date: date}),
  do: where(query, [s, _p, _pr, _prov], s.session_date == ^date)
defp maybe_filter_date(query, _), do: query

defp maybe_filter_date_range(query, %{date_from: from, date_to: to}),
  do: where(query, [s, _p, _pr, _prov], s.session_date >= ^from and s.session_date <= ^to)
defp maybe_filter_date_range(query, _), do: query

defp maybe_filter_provider(query, %{provider_id: id}),
  do: where(query, [_s, p, _pr, _prov], p.provider_id == ^id)
defp maybe_filter_provider(query, _), do: query

defp maybe_filter_program(query, %{program_id: id}),
  do: where(query, [s, _p, _pr, _prov], s.program_id == ^id)
defp maybe_filter_program(query, _), do: query

defp maybe_filter_status(query, %{status: status}),
  do: where(query, [s, _p, _pr, _prov], s.status == ^to_string(status))
defp maybe_filter_status(query, _), do: query

defp atomize_status(%{status: status} = map) when is_binary(status),
  do: %{map | status: String.to_existing_atom(status)}
defp atomize_status(map), do: map
```

Note: Add aliases for `ParticipationRecordSchema` and `ProviderProfileSchema` (from Provider context schemas) at the top of the module. The admin dashboard is a pragmatic exception to strict context boundaries (same as existing Backpex resources). The `GROUP BY` only lists `[s.id, p.title, prov.business_name]` — PostgreSQL allows this because `s.session_date`, `s.start_time`, etc. are functionally dependent on the primary key `s.id`.

```elixir
alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
```

Also check if the `Boundary` config in `lib/klass_hero/participation.ex` needs `KlassHero.Provider` added to its `deps` list. If compile fails with a Boundary violation, add it.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/adapters/driven/persistence/repositories/session_repository_test.exs -v`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/participation/domain/ports/for_managing_sessions.ex \
        lib/klass_hero/participation/adapters/driven/persistence/repositories/session_repository.ex \
        test/klass_hero/participation/adapters/driven/persistence/repositories/session_repository_test.exs
git commit -m "feat: add list_admin_sessions/1 with enriched data for admin dashboard"
```

---

### Task 4: Extend `ListSessions` Use Case for Admin

**Files:**
- Modify: `lib/klass_hero/participation/application/use_cases/list_sessions.ex`
- Modify: `lib/klass_hero/participation.ex`
- Test: `test/klass_hero/participation/application/use_cases/list_sessions_test.exs`

**Context:** Add admin-specific list function that delegates to the new `list_admin_sessions` repository method. Keep existing `execute/1` clauses untouched.

- [ ] **Step 1: Write failing test for `execute_admin/1`**

```elixir
# test/klass_hero/participation/application/use_cases/list_sessions_test.exs
# (add new describe block to existing file, or create if needed)

describe "execute_admin/1" do
  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Test Program")

    insert(:program_session_schema,
      program_id: program.id,
      session_date: Date.utc_today(),
      status: "scheduled"
    )

    %{provider: provider, program: program}
  end

  test "defaults to today when no date filter provided" do
    results = ListSessions.execute_admin(%{})
    assert length(results) == 1
    assert hd(results).program_name == "Test Program"
  end

  test "uses provided date filter instead of default" do
    yesterday = Date.add(Date.utc_today(), -1)
    results = ListSessions.execute_admin(%{date: yesterday})
    assert results == []
  end

  test "passes through provider_id filter" do
    other_provider = insert(:provider_profile_schema)
    results = ListSessions.execute_admin(%{provider_id: other_provider.id})
    assert results == []
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/participation/application/use_cases/list_sessions_test.exs --only describe:"execute_admin/1" -v`
Expected: FAIL — `execute_admin/1` is undefined

- [ ] **Step 3: Add `execute_admin/1` function clause**

```elixir
# Add to lib/klass_hero/participation/application/use_cases/list_sessions.ex

@doc """
Lists sessions with enriched data for admin dashboard.

Returns maps with program_name, provider_name, checked_in_count, total_count.
"""
@spec execute_admin(map()) :: [map()]
def execute_admin(filters \\ %{}) do
  # Trigger: no date/date_range filter provided
  # Why: default to today for the admin "today mode"
  # Outcome: prevents loading all sessions across all time
  filters =
    if not Map.has_key?(filters, :date) and
         not (Map.has_key?(filters, :date_from) and Map.has_key?(filters, :date_to)) do
      Map.put(filters, :date, Date.utc_today())
    else
      filters
    end

  @session_repository.list_admin_sessions(filters)
end
```

- [ ] **Step 4: Expose in context facade**

Add to `lib/klass_hero/participation.ex`:

```elixir
@doc "Lists sessions with enriched data for admin dashboard."
def list_admin_sessions(filters \\ %{}) when is_map(filters) do
  ListSessions.execute_admin(filters)
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/application/use_cases/list_sessions_test.exs -v`
Expected: ALL PASS

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/application/use_cases/list_sessions.ex \
        lib/klass_hero/participation.ex \
        test/klass_hero/participation/application/use_cases/list_sessions_test.exs
git commit -m "feat: expose list_admin_sessions through participation context facade"
```

---

## Chunk 3: Web Layer — Admin Sessions LiveView

### Task 5: Router and Layout Integration

**Files:**
- Modify: `lib/klass_hero_web/router.ex`
- Modify: `lib/klass_hero_web/components/layouts/admin.html.heex`

**Context:** Add route and sidebar item. The custom LiveView needs its own `live_session` because `:backpex_admin` uses `Backpex.InitAssigns` which expects Backpex resources. The admin layout needs the `inner_content`/`inner_block` dual-mode pattern (currently only has `render_slot(@inner_block)`).

- [ ] **Step 1: Add admin sessions live_session to router**

Add to `lib/klass_hero_web/router.ex`. Create a NEW scope block (do NOT put inside the existing `scope "/admin"` that has `pipe_through :backpex_admin` — the backpex pipeline would incorrectly apply). Place it after the existing admin scope block, at the same nesting level:

```elixir
# Place INSIDE the outer `scope "/", KlassHeroWeb do ... pipe_through :browser` block,
# AFTER the existing `scope "/admin", Admin do ... end` block.
# Do NOT place outside the browser scope.
scope "/admin", Admin do
```

Note: The `Boundary` config in `lib/klass_hero/participation.ex` lists `deps: [KlassHero, KlassHero.Family, KlassHero.Shared]`. The admin query in `SessionRepository` now also references `KlassHero.Provider` schemas. The Boundary config may need `KlassHero.Provider` added to deps, or Boundary checking may not apply to the web layer. Verify at compile time and fix if needed.

```elixir
live_session :admin_custom,
  layout: {KlassHeroWeb.Layouts, :admin},
  on_mount: [
    {KlassHeroWeb.UserAuth, :require_authenticated},
    {KlassHeroWeb.UserAuth, :require_admin},
    {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
  ] do
  live "/sessions", SessionsLive, :index
  live "/sessions/:id", SessionsLive, :show
end
```

- [ ] **Step 2: Add dual-mode rendering to admin layout**

Modify `lib/klass_hero_web/components/layouts/admin.html.heex` — replace `{render_slot(@inner_block)}` with:

```heex
<%= if assigns[:inner_content] do %>
  {@inner_content}
<% else %>
  {render_slot(@inner_block)}
<% end %>
```

- [ ] **Step 3: Add sidebar item**

Add to `lib/klass_hero_web/components/layouts/admin.html.heex` after the Bookings sidebar item:

```heex
<Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/sessions"}>
  <Backpex.HTML.CoreComponents.icon name="hero-calendar-days" class="h-5 w-5" /> {gettext(
    "Sessions"
  )}
</Backpex.HTML.Layout.sidebar_item>
```

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero_web/router.ex \
        lib/klass_hero_web/components/layouts/admin.html.heex
git commit -m "feat: add admin sessions route and sidebar item"
```

---

### Task 6: Sessions LiveView — Index Page (Today Mode)

**Files:**
- Create: `lib/klass_hero_web/live/admin/sessions_live.ex`
- Create: `lib/klass_hero_web/live/admin/sessions_live.html.heex`
- Test: `test/klass_hero_web/live/admin/sessions_live_test.exs`

**Context:** Custom LiveView with `layout: {KlassHeroWeb.Layouts, :admin}`. Must assign `fluid?: false`, `live_resource: nil`, and `current_url` for the Backpex admin shell. Uses LiveView streams for the session list. Starts in `:today` mode.

Docs to check:
- Phoenix LiveView streams: `mix usage_rules.docs Phoenix.LiveView.stream/3`
- `handle_params` for URL-driven state: `mix usage_rules.docs Phoenix.LiveView.handle_params/3`

- [ ] **Step 1: Write failing tests for index page**

```elixir
# test/klass_hero_web/live/admin/sessions_live_test.exs

defmodule KlassHeroWeb.Admin.SessionsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import KlassHero.Factory

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/sessions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "Sessions"
    end
  end

  describe "non-admin access" do
    setup :register_and_log_in_user

    test "non-admin is redirected", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/admin/sessions")

      assert flash["error"] =~ "access"
    end
  end

  describe "today mode" do
    setup :register_and_log_in_admin

    setup do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Art Adventures")

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          start_time: ~T[09:00:00],
          end_time: ~T[10:30:00],
          status: "in_progress"
        )

      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()
      {child, parent} = insert_child_with_guardian()

      insert(:participation_record_schema,
        session_id: session.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :checked_in,
        check_in_at: DateTime.utc_now(),
        check_in_by: user.id
      )

      %{session: session, program: program, provider: provider}
    end

    test "displays today's sessions with program name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")
      assert has_element?(view, "#sessions-list")
      assert render(view) =~ "Art Adventures"
    end

    test "shows attendance count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "1 / 1"
    end

    test "shows session status badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "In Progress" or html =~ "in_progress"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/sessions_live_test.exs -v`
Expected: FAIL — module `KlassHeroWeb.Admin.SessionsLive` is not available

- [ ] **Step 3: Implement LiveView module**

```elixir
# lib/klass_hero_web/live/admin/sessions_live.ex

defmodule KlassHeroWeb.Admin.SessionsLive do
  @moduledoc """
  Admin dashboard for participation sessions.

  Two modes:
  - `:today` (default) — shows all sessions for today
  - `:filter` — shows filtered sessions across any date range
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Participation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:fluid?, false)
     |> assign(:live_resource, nil)
     |> assign(:mode, :today)
     |> assign(:filters, %{})
     |> assign(:page_title, gettext("Sessions"))}
  end

  @impl true
  def handle_params(params, uri, socket) do
    current_url = URI.parse(uri).path

    socket =
      socket
      |> assign(:current_url, current_url)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    sessions = Participation.list_admin_sessions(%{date: Date.utc_today()})
    stream(socket, :sessions, sessions, reset: true)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Participation.get_session_with_roster_enriched(id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:editing_record_id, nil)
        |> assign(:correction_form, nil)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, gettext("Session not found"))
        |> push_navigate(to: ~p"/admin/sessions")
    end
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    # Note: ALL handle_event clauses share the @impl true above.
    mode = String.to_existing_atom(mode)

    socket =
      case mode do
        :today ->
          sessions = Participation.list_admin_sessions(%{date: Date.utc_today()})

          socket
          |> assign(:mode, :today)
          |> assign(:filters, %{})
          |> stream(:sessions, sessions, reset: true)

        :filter ->
          assign(socket, :mode, :filter)
      end

    {:noreply, socket}
  end

  def handle_event("apply_filters", params, socket) do
    filters = build_filters_from_params(params)
    sessions = Participation.list_admin_sessions(filters)

    socket =
      socket
      |> assign(:filters, filters)
      |> stream(:sessions, sessions, reset: true)

    {:noreply, socket}
  end

  def handle_event("open_correction", %{"record-id" => record_id}, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, record_id)
     |> assign(:correction_form, to_form(%{"reason" => ""}, as: :correction))}
  end

  def handle_event("cancel_correction", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, nil)
     |> assign(:correction_form, nil)}
  end

  def handle_event("save_correction", %{"correction" => correction_params}, socket) do
    record_id = socket.assigns.editing_record_id

    params =
      %{record_id: record_id, reason: correction_params["reason"]}
      |> maybe_put_status(correction_params)
      |> maybe_put_time(:check_in_at, correction_params["check_in_at"])
      |> maybe_put_time(:check_out_at, correction_params["check_out_at"])

    case Participation.correct_attendance(params) do
      {:ok, _corrected} ->
        # Refetch session detail to reflect changes
        {:ok, session} =
          Participation.get_session_with_roster_enriched(socket.assigns.session.id)

        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:editing_record_id, nil)
         |> assign(:correction_form, nil)
         |> put_flash(:info, gettext("Attendance corrected successfully"))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  # -- Private Helpers --

  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:provider_id, params["provider_id"])
    |> maybe_add_filter(:program_id, params["program_id"])
    |> maybe_add_filter(:status, parse_status(params["status"]))
    |> maybe_add_date_filter(params)
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_date_filter(filters, %{"date_from" => from, "date_to" => to})
       when from != "" and to != "" do
    Map.merge(filters, %{
      date_from: Date.from_iso8601!(from),
      date_to: Date.from_iso8601!(to)
    })
  end

  defp maybe_add_date_filter(filters, _params),
    do: Map.put(filters, :date, Date.utc_today())

  defp parse_status(""), do: nil
  defp parse_status(nil), do: nil
  defp parse_status(status), do: String.to_existing_atom(status)

  defp maybe_put_status(params, %{"status" => ""}), do: params
  defp maybe_put_status(params, %{"status" => s}), do: Map.put(params, :status, String.to_existing_atom(s))
  defp maybe_put_status(params, _), do: params

  defp maybe_put_time(params, _key, nil), do: params
  defp maybe_put_time(params, _key, ""), do: params

  defp maybe_put_time(params, key, time_string) do
    # Trigger: datetime-local inputs submit "YYYY-MM-DDTHH:MM" (no timezone)
    # Why: DateTime.from_iso8601 requires a timezone offset and would fail
    # Outcome: parse as NaiveDateTime, then convert to UTC DateTime
    case NaiveDateTime.from_iso8601(time_string) do
      {:ok, ndt} -> Map.put(params, key, DateTime.from_naive!(ndt, "Etc/UTC"))
      _ -> params
    end
  end

  defp error_message(:reason_required), do: gettext("A reason is required for corrections")
  defp error_message(:no_changes), do: gettext("No changes detected")
  defp error_message(:not_found), do: gettext("Record not found")
  defp error_message(:stale_data), do: gettext("Record was modified by someone else. Please refresh.")
  defp error_message(:check_out_requires_check_in), do: gettext("Cannot check out without a check-in")
  defp error_message(_), do: gettext("An error occurred")
end
```

- [ ] **Step 4: Implement template**

Create `lib/klass_hero_web/live/admin/sessions_live.html.heex`.

**Data shape note:** `get_session_with_roster_enriched/1` returns a plain map (not a struct) with key `:id`, `:session_date`, `:start_time`, `:end_time`, `:status`, `:program_id`, and `:participation_records` — a list of plain maps, each with merged child info fields (`:child_name`, `:child_first_name`, `:child_last_name`, `:allergies`, `:support_needs`) plus standard record fields (`:id`, `:status`, `:check_in_at`, `:check_out_at`, etc.) and `:behavioral_notes` (list of note structs).

```heex
<%!-- Index view --%>
<div :if={@live_action == :index}>
  <div class="mb-6">
    <h1 class={Theme.typography(:page_title)}>{gettext("Sessions")}</h1>
  </div>

  <%!-- Mode switcher --%>
  <div class="flex items-center gap-3 mb-4 border-b border-base-300 pb-2">
    <button
      id="mode-today"
      phx-click="switch_mode"
      phx-value-mode="today"
      class={["text-sm font-medium px-3 py-1 rounded", @mode == :today && "bg-primary text-primary-content"]}
    >
      {gettext("Today")}
    </button>
    <button
      id="mode-filter"
      phx-click="switch_mode"
      phx-value-mode="filter"
      class={["text-sm font-medium px-3 py-1 rounded", @mode == :filter && "bg-primary text-primary-content"]}
    >
      {gettext("Search & Filter")}
    </button>
  </div>

  <%!-- Filter form (filter mode only) --%>
  <form :if={@mode == :filter} id="filter-form" phx-submit="apply_filters" class="flex flex-wrap gap-3 mb-4">
    <input type="text" name="provider_id" placeholder={gettext("Provider ID")} class="input input-bordered input-sm" value={@filters[:provider_id]} />
    <input type="text" name="program_id" placeholder={gettext("Program ID")} class="input input-bordered input-sm" value={@filters[:program_id]} />
    <input type="date" name="date_from" class="input input-bordered input-sm" value={@filters[:date_from]} />
    <input type="date" name="date_to" class="input input-bordered input-sm" value={@filters[:date_to]} />
    <select name="status" class="select select-bordered select-sm">
      <option value="">{gettext("All Statuses")}</option>
      <option value="scheduled">{gettext("Scheduled")}</option>
      <option value="in_progress">{gettext("In Progress")}</option>
      <option value="completed">{gettext("Completed")}</option>
      <option value="cancelled">{gettext("Cancelled")}</option>
    </select>
    <button type="submit" class="btn btn-primary btn-sm">{gettext("Apply")}</button>
  </form>

  <%!-- Session list (stream). Empty state uses CSS only:block trick (streams are not enumerable). --%>
  <div id="sessions-list" phx-update="stream" class="space-y-1">
    <div class="hidden only:block text-center text-sm opacity-50 py-8">
      {gettext("No sessions found")}
    </div>
    <.link
      :for={{dom_id, session} <- @streams.sessions}
      id={dom_id}
      navigate={~p"/admin/sessions/#{session.id}"}
      class="block p-4 rounded-lg border border-base-300 hover:bg-base-200 transition"
    >
      <div class="flex justify-between items-center flex-wrap gap-2">
        <div>
          <div class="font-semibold text-sm">{session.program_name}</div>
          <div class="text-xs opacity-50 mt-0.5">
            {session.provider_name}
            · {if @mode == :filter, do: "#{session.session_date} · "}
            {Calendar.strftime(session.start_time, "%H:%M")}–{Calendar.strftime(session.end_time, "%H:%M")}
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span class={["badge badge-sm", status_badge_class(session.status)]}>
            {humanize_status(session.status)}
          </span>
          <span :if={session.status != :cancelled} class="text-sm font-medium">
            {session.checked_in_count} / {session.total_count}
          </span>
        </div>
      </div>
    </.link>
  </div>
</div>

<%!-- Show view --%>
<div :if={@live_action == :show}>
  <div class="mb-6">
    <.link navigate={~p"/admin/sessions"} class="text-sm opacity-50 hover:opacity-100 mb-2 inline-block">
      ← {gettext("Back to sessions")}
    </.link>
    <div class="flex justify-between items-start flex-wrap gap-2">
      <div>
        <h1 class={Theme.typography(:section_title)}>{@session.program_name || @session.program_id}</h1>
        <div class="text-sm opacity-50 mt-1">
          {@session.session_date}
          · {Calendar.strftime(@session.start_time, "%H:%M")}–{Calendar.strftime(@session.end_time, "%H:%M")}
        </div>
      </div>
      <span class={["badge", status_badge_class(@session.status)]}>
        {humanize_status(@session.status)}
      </span>
    </div>
  </div>

  <%!-- Roster table --%>
  <div class="overflow-x-auto" id="roster-table">
    <table class="table table-sm">
      <thead>
        <tr>
          <th>{gettext("Child")}</th>
          <th>{gettext("Status")}</th>
          <th>{gettext("Check-in")}</th>
          <th>{gettext("Check-out")}</th>
          <th>{gettext("Notes")}</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <%= for record <- @session.participation_records do %>
          <tr id={"record-#{record.id}"}>
            <td class="font-medium">{record.child_name}</td>
            <td>
              <span class={["badge badge-sm", record_status_class(record.status)]}>
                {humanize_status(record.status)}
              </span>
            </td>
            <td>{format_time(record.check_in_at)}</td>
            <td>{format_time(record.check_out_at)}</td>
            <td>{note_badge(record)}</td>
            <td class="text-right">
              <button
                id={"correct-#{record.id}"}
                phx-click="open_correction"
                phx-value-record-id={record.id}
                class="text-xs text-primary hover:underline"
              >
                {gettext("Correct")}
              </button>
            </td>
          </tr>

          <%!-- Inline correction form --%>
          <%= if @editing_record_id == record.id do %>
            <tr>
              <td colspan="6" class="bg-base-200 border-l-4 border-primary">
                <.form for={@correction_form} id="correction-form" phx-submit="save_correction" class="p-4 space-y-3">
                  <div class="flex flex-wrap gap-3">
                    <div class="form-control">
                      <label class="label label-text text-xs">{gettext("Status")}</label>
                      <select name="correction[status]" class="select select-bordered select-sm">
                        <option value="">{gettext("No change")}</option>
                        <option value="registered">{gettext("Registered")}</option>
                        <option value="checked_in">{gettext("Checked In")}</option>
                        <option value="checked_out">{gettext("Checked Out")}</option>
                        <option value="absent">{gettext("Absent")}</option>
                      </select>
                    </div>
                    <div class="form-control">
                      <label class="label label-text text-xs">{gettext("Check-in time")}</label>
                      <input type="datetime-local" name="correction[check_in_at]" class="input input-bordered input-sm" value={format_datetime_local(record.check_in_at)} />
                    </div>
                    <div class="form-control">
                      <label class="label label-text text-xs">{gettext("Check-out time")}</label>
                      <input type="datetime-local" name="correction[check_out_at]" class="input input-bordered input-sm" value={format_datetime_local(record.check_out_at)} />
                    </div>
                  </div>
                  <div class="form-control">
                    <label class="label label-text text-xs">{gettext("Reason for correction")} *</label>
                    <textarea name="correction[reason]" class="textarea textarea-bordered textarea-sm" required placeholder={gettext("Explain why this correction is needed...")}></textarea>
                  </div>
                  <div class="flex gap-2 justify-end">
                    <button type="button" id="cancel-correction" phx-click="cancel_correction" class="btn btn-ghost btn-sm">
                      {gettext("Cancel")}
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm">
                      {gettext("Save Correction")}
                    </button>
                  </div>
                </.form>
              </td>
            </tr>
          <% end %>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

Add helper functions at the bottom of the LiveView module (`sessions_live.ex`):

```elixir
defp status_badge_class(:scheduled), do: "badge-info"
defp status_badge_class(:in_progress), do: "badge-success"
defp status_badge_class(:completed), do: "badge-secondary"
defp status_badge_class(:cancelled), do: "badge-error"
defp status_badge_class(_), do: ""

defp record_status_class(:registered), do: "badge-ghost"
defp record_status_class(:checked_in), do: "badge-success"
defp record_status_class(:checked_out), do: "badge-secondary"
defp record_status_class(:absent), do: "badge-error"
defp record_status_class(_), do: ""

defp humanize_status(:in_progress), do: gettext("In Progress")
defp humanize_status(:checked_in), do: gettext("Checked In")
defp humanize_status(:checked_out), do: gettext("Checked Out")
defp humanize_status(status), do: status |> to_string() |> String.capitalize()

defp format_time(nil), do: "—"
defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")

defp format_datetime_local(nil), do: ""
defp format_datetime_local(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%dT%H:%M")

defp note_badge(record) do
  notes = Map.get(record, :behavioral_notes, [])
  case notes do
    [] -> "—"
    notes ->
      # Show the most relevant status
      cond do
        Enum.any?(notes, & &1.status == :approved) -> "Approved"
        Enum.any?(notes, & &1.status == :pending_approval) -> "Pending"
        true -> "—"
      end
  end
end
```

**Important:** Use `String.to_existing_atom/1` for status parsing in handle_event. The atoms `:scheduled`, `:in_progress`, `:completed`, `:cancelled`, `:registered`, `:checked_in`, `:checked_out`, `:absent` are already defined by the domain model, so `to_existing_atom` is safe. If a malicious string is submitted, it raises — which is the correct behavior (let it crash).

**Pagination:** The spec mentions cursor-based pagination for filter mode. This is deferred to a follow-up issue to keep the initial implementation focused. Add a TODO issue after the main work is complete.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/admin/sessions_live_test.exs -v`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/admin/sessions_live.ex \
        lib/klass_hero_web/live/admin/sessions_live.html.heex \
        test/klass_hero_web/live/admin/sessions_live_test.exs
git commit -m "feat: add admin sessions LiveView with today mode and roster display"
```

---

### Task 7: Sessions LiveView — Additional Tests (filter mode + correction flow)

**Files:**
- Modify: `test/klass_hero_web/live/admin/sessions_live_test.exs`

**Context:** Task 6 included basic index tests (TDD: tests before implementation). This task adds the remaining tests for filter mode and correction flow. These tests validate event handlers already implemented in Task 6 — the TDD cycle was completed for the core index rendering in Task 6; these are additional coverage tests for the interactive behaviors.

- [ ] **Step 1: Add filter mode tests**

```elixir
describe "filter mode" do
  setup :register_and_log_in_admin

  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Soccer Training")

    insert(:program_session_schema,
      program_id: program.id,
      session_date: Date.utc_today(),
      status: "completed"
    )

    %{provider: provider, program: program}
  end

  test "switches to filter mode", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")

    view |> element("#mode-filter") |> render_click()
    assert has_element?(view, "#filter-form")
  end

  test "switches back to today mode", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")

    view |> element("#mode-filter") |> render_click()
    view |> element("#mode-today") |> render_click()
    refute has_element?(view, "#filter-form")
  end
end
```

- [ ] **Step 2: Add correction flow tests**

```elixir
describe "correction flow" do
  setup :register_and_log_in_admin

  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()

    session =
      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: "in_progress"
      )

    {child, parent} = insert_child_with_guardian(first_name: "Emma")

    record =
      insert(:participation_record_schema,
        session_id: session.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :checked_in,
        check_in_at: ~U[2026-03-13 09:00:00Z],
        check_in_by: user.id
      )

    %{session: session, record: record}
  end

  test "opens correction form for a record", %{conn: conn, session: session, record: record} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

    view |> element("#correct-#{record.id}") |> render_click()
    assert has_element?(view, "#correction-form")
  end

  test "cancels correction", %{conn: conn, session: session, record: record} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

    view |> element("#correct-#{record.id}") |> render_click()
    view |> element("#cancel-correction") |> render_click()
    refute has_element?(view, "#correction-form")
  end

  test "saves correction with reason", %{conn: conn, session: session, record: record} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

    view |> element("#correct-#{record.id}") |> render_click()

    view
    |> form("#correction-form", %{
      correction: %{
        status: "checked_out",
        check_out_at: "2026-03-13T10:30",
        reason: "Provider forgot to check out"
      }
    })
    |> render_submit()

    assert render(view) =~ "corrected successfully"
  end

  test "shows error when reason is blank", %{conn: conn, session: session, record: record} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

    view |> element("#correct-#{record.id}") |> render_click()

    view
    |> form("#correction-form", %{
      correction: %{status: "absent", reason: ""}
    })
    |> render_submit()

    assert render(view) =~ "reason"
  end
end
```

- [ ] **Step 3: Run tests**

Run: `mix test test/klass_hero_web/live/admin/sessions_live_test.exs -v`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
git add test/klass_hero_web/live/admin/sessions_live_test.exs
git commit -m "test: add filter mode and correction flow tests for admin sessions"
```

---

## Chunk 4: Finalization

### Task 8: Gettext Translations

**Files:**
- Run: `mix gettext.extract --merge`
- Update: `priv/gettext/de/LC_MESSAGES/default.po` with German translations

- [ ] **Step 1: Extract and merge gettext strings**

Run: `mix gettext.extract --merge`

- [ ] **Step 2: Add German translations**

Key strings to translate in `priv/gettext/de/LC_MESSAGES/default.po`:
- "Sessions" → "Sitzungen"
- "Session not found" → "Sitzung nicht gefunden"
- "Attendance corrected successfully" → "Anwesenheit erfolgreich korrigiert"
- "A reason is required for corrections" → "Ein Grund für die Korrektur ist erforderlich"
- "No changes detected" → "Keine Änderungen erkannt"
- "Record was modified by someone else. Please refresh." → "Datensatz wurde von jemand anderem geändert. Bitte aktualisieren."
- "Cannot check out without a check-in" → "Auschecken ohne Einchecken nicht möglich"
- "An error occurred" → "Ein Fehler ist aufgetreten"

- [ ] **Step 3: Commit**

```bash
git add priv/gettext/
git commit -m "feat: add German translations for admin sessions dashboard"
```

---

### Task 9: Pre-commit Checks and Final Validation

- [ ] **Step 1: Run pre-commit checks**

Run: `mix precommit`

This runs: compile with `--warnings-as-errors`, `deps.unlock --unused`, `mix format`, `mix test`

Expected: ALL PASS with zero warnings

- [ ] **Step 2: Fix any issues found**

Address warnings, formatting issues, or test failures.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address precommit issues for admin sessions"
```
