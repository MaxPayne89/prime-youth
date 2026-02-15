# Program Scheduling Fields Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the unstructured `schedule` string with structured scheduling fields (meeting days, times, dates) on programs.

**Architecture:** Add flat columns to `programs` table, update domain model/schema/mapper, add presenter formatting, update provider form UI, emit new domain event.

**Tech Stack:** Elixir, Ecto, Phoenix LiveView, HEEx, ExUnit

---

### Task 1: Migration — add structured columns, drop schedule

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_program_scheduling_fields.exs`

**Step 1: Create migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddProgramSchedulingFields do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :meeting_days, {:array, :string}, default: [], null: false
      add :meeting_start_time, :time
      add :meeting_end_time, :time
      add :start_date, :date
      remove :schedule, :string
    end
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds

**Step 3: Commit**

```
feat: add scheduling fields migration (#146)
```

---

### Task 2: Domain Model — replace schedule with structured fields

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`
- Modify: `test/klass_hero/program_catalog/domain/models/program_test.exs`

**Step 1: Write failing tests for scheduling validation**

Add to `program_test.exs` — new `describe "scheduling validation"` block:

```elixir
describe "scheduling validation in create/1" do
  defp scheduling_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Scheduled Program",
        description: "Has a schedule",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      },
      overrides
    )
  end

  test "accepts valid scheduling fields" do
    attrs = scheduling_attrs(%{
      meeting_days: ["Monday", "Wednesday"],
      meeting_start_time: ~T[16:00:00],
      meeting_end_time: ~T[17:30:00],
      start_date: ~D[2026-03-01],
      end_date: ~D[2026-06-30]
    })

    assert {:ok, program} = Program.create(attrs)
    assert program.meeting_days == ["Monday", "Wednesday"]
    assert program.meeting_start_time == ~T[16:00:00]
    assert program.meeting_end_time == ~T[17:30:00]
    assert program.start_date == ~D[2026-03-01]
  end

  test "accepts empty scheduling fields" do
    attrs = scheduling_attrs()
    assert {:ok, program} = Program.create(attrs)
    assert program.meeting_days == []
    assert program.meeting_start_time == nil
    assert program.meeting_end_time == nil
    assert program.start_date == nil
  end

  test "rejects invalid weekday names" do
    attrs = scheduling_attrs(%{meeting_days: ["Monday", "Funday"]})
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "meeting_days"))
  end

  test "rejects start_time without end_time" do
    attrs = scheduling_attrs(%{meeting_start_time: ~T[16:00:00]})
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "time"))
  end

  test "rejects end_time without start_time" do
    attrs = scheduling_attrs(%{meeting_end_time: ~T[17:00:00]})
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "time"))
  end

  test "rejects end_time not after start_time" do
    attrs = scheduling_attrs(%{
      meeting_start_time: ~T[17:00:00],
      meeting_end_time: ~T[16:00:00]
    })
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "time"))
  end

  test "rejects equal start and end times" do
    attrs = scheduling_attrs(%{
      meeting_start_time: ~T[16:00:00],
      meeting_end_time: ~T[16:00:00]
    })
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "time"))
  end

  test "rejects start_date after end_date" do
    attrs = scheduling_attrs(%{
      start_date: ~D[2026-06-30],
      end_date: ~D[2026-03-01]
    })
    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "date"))
  end
end
```

Also add a test for `apply_changes/2`:

```elixir
describe "apply_changes/2 scheduling" do
  test "updates scheduling fields" do
    program = existing_program()
    changes = %{
      meeting_days: ["Tuesday", "Thursday"],
      meeting_start_time: ~T[15:00:00],
      meeting_end_time: ~T[16:30:00],
      start_date: ~D[2026-04-01]
    }

    assert {:ok, updated} = Program.apply_changes(program, changes)
    assert updated.meeting_days == ["Tuesday", "Thursday"]
    assert updated.meeting_start_time == ~T[15:00:00]
  end

  test "rejects invalid scheduling changes" do
    program = existing_program()
    changes = %{
      meeting_start_time: ~T[17:00:00],
      meeting_end_time: ~T[16:00:00]
    }

    assert {:error, errors} = Program.apply_changes(program, changes)
    assert Enum.any?(errors, &String.contains?(&1, "time"))
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs --max-failures 3`
Expected: FAIL — `schedule` field references and missing new fields

**Step 3: Update the Program domain model**

In `program.ex`:

1. Remove `:schedule` from defstruct (line 20) and @type (line 41)
2. Add new fields to defstruct:
   ```elixir
   :meeting_start_time,
   :meeting_end_time,
   :start_date,
   meeting_days: [],
   ```
3. Update @type:
   ```elixir
   meeting_days: [String.t()],
   meeting_start_time: Time.t() | nil,
   meeting_end_time: Time.t() | nil,
   start_date: Date.t() | nil,
   ```
4. Update `build_base/2` (line 161-184): replace `schedule: attrs[:schedule]` with:
   ```elixir
   meeting_days: attrs[:meeting_days] || [],
   meeting_start_time: attrs[:meeting_start_time],
   meeting_end_time: attrs[:meeting_end_time],
   start_date: attrs[:start_date],
   ```
5. Add scheduling validation to `validate_creation_invariants/1` (line 187):
   ```elixir
   |> validate_scheduling(attrs)
   ```
6. Update `@updatable_fields` (line 251): replace `:schedule` with `:meeting_days, :meeting_start_time, :meeting_end_time, :start_date`
7. Add validation to `validate_mutation_invariants/1` (line 267):
   ```elixir
   |> validate_scheduling(struct_fields)
   ```
8. Add scheduling validation functions:
   ```elixir
   @valid_weekdays ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

   defp validate_scheduling(errors, attrs) do
     errors
     |> validate_meeting_days(attrs[:meeting_days])
     |> validate_time_pairing(attrs[:meeting_start_time], attrs[:meeting_end_time])
     |> validate_date_range(attrs[:start_date], attrs[:end_date])
   end

   defp validate_meeting_days(errors, nil), do: errors
   defp validate_meeting_days(errors, []), do: errors

   defp validate_meeting_days(errors, days) when is_list(days) do
     if Enum.all?(days, &(&1 in @valid_weekdays)) do
       errors
     else
       ["meeting_days contains invalid weekday names" | errors]
     end
   end

   defp validate_meeting_days(errors, _), do: ["meeting_days must be a list" | errors]

   defp validate_time_pairing(errors, nil, nil), do: errors

   defp validate_time_pairing(errors, %Time{} = start_time, %Time{} = end_time) do
     if Time.compare(end_time, start_time) == :gt do
       errors
     else
       ["meeting_end_time must be after meeting_start_time" | errors]
     end
   end

   defp validate_time_pairing(errors, _, _) do
     ["both meeting_start_time and meeting_end_time must be set together" | errors]
   end

   defp validate_date_range(errors, nil, _), do: errors
   defp validate_date_range(errors, _, nil), do: errors

   defp validate_date_range(errors, %Date{} = start_date, %Date{} = end_date) do
     if Date.compare(start_date, end_date) == :lt do
       errors
     else
       ["start_date must be before end_date" | errors]
     end
   end

   # Trigger: end_date may be DateTime (existing data) rather than Date
   # Why: end_date column is :utc_datetime — comparison still valid
   # Outcome: convert DateTime to Date for comparison
   defp validate_date_range(errors, %Date{} = start_date, %DateTime{} = end_dt) do
     validate_date_range(errors, start_date, DateTime.to_date(end_dt))
   end

   defp validate_date_range(errors, _, _), do: errors
   ```

**Step 4: Fix existing tests that reference `schedule`**

Throughout `program_test.exs`, remove all `schedule: "..."` from test attrs and struct literals. The `valid_attrs/1` helper should drop `schedule` and add `meeting_days: []`.

**Step 5: Run tests**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: All PASS

**Step 6: Commit**

```
feat: add scheduling fields to Program domain model (#146)
```

---

### Task 3: Schema — update ProgramSchema with new columns

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`
- Modify: `test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs`

**Step 1: Write failing tests for new schema fields**

Add tests for the new changeset validations (meeting_days subset, time pairing, date ordering).

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs --max-failures 3`
Expected: FAIL

**Step 3: Update ProgramSchema**

1. Remove `field :schedule, :string` (line 22)
2. Add new fields after removing schedule:
   ```elixir
   field :meeting_days, {:array, :string}, default: []
   field :meeting_start_time, :time
   field :meeting_end_time, :time
   field :start_date, :date
   ```
3. Update `@type` — remove `schedule`, add new field types
4. Update `changeset/2` (line 79-117): remove `:schedule` from cast list, validate_required, and validate_length. Add:
   ```elixir
   |> validate_meeting_days()
   |> validate_time_pairing()
   |> validate_date_range()
   ```
5. Update `create_changeset/2` (line 125-154): add `:meeting_days, :meeting_start_time, :meeting_end_time, :start_date` to cast. Add same custom validations.
6. Update `update_changeset/2` (line 165-200): replace `:schedule` in cast with new fields. Remove schedule length validation. Add custom validations.
7. Add private validation functions:
   ```elixir
   @valid_weekdays ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

   defp validate_meeting_days(changeset) do
     validate_change(changeset, :meeting_days, fn :meeting_days, days ->
       invalid = Enum.reject(days, &(&1 in @valid_weekdays))

       if invalid == [] do
         []
       else
         [{:meeting_days, "contains invalid days: #{Enum.join(invalid, ", ")}"}]
       end
     end)
   end

   defp validate_time_pairing(changeset) do
     start_time = get_field(changeset, :meeting_start_time)
     end_time = get_field(changeset, :meeting_end_time)

     cond do
       is_nil(start_time) and is_nil(end_time) ->
         changeset

       is_nil(start_time) or is_nil(end_time) ->
         add_error(changeset, :meeting_start_time, "both start and end times must be set together")

       Time.compare(end_time, start_time) != :gt ->
         add_error(changeset, :meeting_end_time, "must be after start time")

       true ->
         changeset
     end
   end

   defp validate_date_range(changeset) do
     start_date = get_field(changeset, :start_date)
     end_date = get_field(changeset, :end_date)

     cond do
       is_nil(start_date) or is_nil(end_date) ->
         changeset

       Date.compare(start_date, end_date) != :lt ->
         add_error(changeset, :start_date, "must be before end date")

       true ->
         changeset
     end
   end
   ```

**Step 4: Run tests**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs`
Expected: All PASS

**Step 5: Commit**

```
feat: add scheduling fields to ProgramSchema (#146)
```

---

### Task 4: Mapper — update bidirectional mapping

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`
- Modify: `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`

**Step 1: Write failing tests**

Test that `to_domain/1` maps the new fields and `to_schema/1` maps them back.

**Step 2: Run to verify failure**

**Step 3: Update ProgramMapper**

In `to_domain/1` (line 44-65): replace `schedule: schema.schedule` with:
```elixir
meeting_days: schema.meeting_days || [],
meeting_start_time: schema.meeting_start_time,
meeting_end_time: schema.meeting_end_time,
start_date: schema.start_date,
```

In `to_schema/1` (line 112-130): replace `schedule: program.schedule` with:
```elixir
meeting_days: program.meeting_days,
meeting_start_time: program.meeting_start_time,
meeting_end_time: program.meeting_end_time,
start_date: program.start_date,
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`
Expected: All PASS

**Step 5: Commit**

```
feat: update ProgramMapper for scheduling fields (#146)
```

---

### Task 5: Presenter — add schedule formatting

**Files:**
- Modify: `lib/klass_hero_web/presenters/program_presenter.ex`
- Modify: `test/klass_hero_web/presenters/program_presenter_test.exs`

**Step 1: Write failing tests for format_schedule/1**

```elixir
describe "format_schedule/1" do
  test "formats full schedule with days, times, and dates" do
    program = build(:program,
      meeting_days: ["Monday", "Wednesday"],
      meeting_start_time: ~T[16:00:00],
      meeting_end_time: ~T[17:30:00],
      start_date: ~D[2026-03-01],
      end_date: ~U[2026-06-30 00:00:00Z]
    )

    result = ProgramPresenter.format_schedule(program)
    assert result.days == "Mon & Wed"
    assert result.times == "4:00 - 5:30 PM"
    assert result.date_range =~ "Mar 1"
    assert result.date_range =~ "Jun 30"
  end

  test "returns nil when no scheduling data" do
    program = build(:program, meeting_days: [], meeting_start_time: nil)
    assert ProgramPresenter.format_schedule(program) == nil
  end

  test "formats single day" do
    program = build(:program, meeting_days: ["Saturday"])
    result = ProgramPresenter.format_schedule(program)
    assert result.days == "Sat"
  end

  test "formats three days with Oxford comma" do
    program = build(:program, meeting_days: ["Monday", "Wednesday", "Friday"])
    result = ProgramPresenter.format_schedule(program)
    assert result.days == "Mon, Wed & Fri"
  end

  test "formats days only when no times set" do
    program = build(:program,
      meeting_days: ["Monday", "Wednesday"],
      meeting_start_time: nil,
      meeting_end_time: nil
    )
    result = ProgramPresenter.format_schedule(program)
    assert result.days == "Mon & Wed"
    assert result.times == nil
  end

  test "formats times crossing AM/PM" do
    program = build(:program,
      meeting_days: ["Saturday"],
      meeting_start_time: ~T[11:00:00],
      meeting_end_time: ~T[13:30:00]
    )
    result = ProgramPresenter.format_schedule(program)
    assert result.times == "11:00 AM - 1:30 PM"
  end
end
```

**Step 2: Run to verify failure**

**Step 3: Implement format_schedule/1**

Add to `program_presenter.ex`:

```elixir
@day_abbreviations %{
  "Monday" => "Mon", "Tuesday" => "Tue", "Wednesday" => "Wed",
  "Thursday" => "Thu", "Friday" => "Fri", "Saturday" => "Sat", "Sunday" => "Sun"
}

@doc """
Formats a program's scheduling fields for display.

Returns a map with :days, :times, :date_range keys, or nil if no scheduling data.
"""
@spec format_schedule(Program.t()) :: %{days: String.t(), times: String.t() | nil, date_range: String.t() | nil} | nil
def format_schedule(%Program{meeting_days: days} = program) when days == [] or is_nil(days) do
  if is_nil(program.meeting_start_time) and is_nil(program.start_date) do
    nil
  else
    %{
      days: nil,
      times: format_times(program.meeting_start_time, program.meeting_end_time),
      date_range: format_date_range(program.start_date, program.end_date)
    }
  end
end

def format_schedule(%Program{} = program) do
  %{
    days: format_days(program.meeting_days),
    times: format_times(program.meeting_start_time, program.meeting_end_time),
    date_range: format_date_range(program.start_date, program.end_date)
  }
end

defp format_days([day]), do: Map.get(@day_abbreviations, day, day)

defp format_days([d1, d2]) do
  "#{Map.get(@day_abbreviations, d1, d1)} & #{Map.get(@day_abbreviations, d2, d2)}"
end

defp format_days(days) when is_list(days) do
  {last, rest} = List.pop_at(days, -1)
  abbreviated = Enum.map(rest, &Map.get(@day_abbreviations, &1, &1))
  "#{Enum.join(abbreviated, ", ")} & #{Map.get(@day_abbreviations, last, last)}"
end

defp format_times(nil, _), do: nil
defp format_times(_, nil), do: nil

defp format_times(%Time{} = start_time, %Time{} = end_time) do
  "#{format_time_12h(start_time)} - #{format_time_12h(end_time)}"
end

defp format_time_12h(%Time{hour: hour, minute: minute}) do
  {h12, period} = if hour >= 12, do: {rem(hour, 12), "PM"}, else: {hour, "AM"}
  h12 = if h12 == 0, do: 12, else: h12
  "#{h12}:#{String.pad_leading("#{minute}", 2, "0")} #{period}"
end

defp format_date_range(nil, _), do: nil
defp format_date_range(_, nil), do: nil

defp format_date_range(%Date{} = start_date, end_date) do
  end_date = if match?(%DateTime{}, end_date), do: DateTime.to_date(end_date), else: end_date
  "#{format_short_date(start_date)} - #{format_short_date(end_date)}, #{end_date.year}"
end

defp format_short_date(%Date{} = date) do
  month = Enum.at(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec), date.month - 1)
  "#{month} #{date.day}"
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero_web/presenters/program_presenter_test.exs`
Expected: All PASS

**Step 5: Commit**

```
feat: add schedule formatting to ProgramPresenter (#146)
```

---

### Task 6: Provider Form — add scheduling UI

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex:719-885` (program_form/1)
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex:444-505` (save_program handler)

**Step 1: Add scheduling section to program_form component**

Insert between the Location input (line 779) and Description textarea (line 782) in `provider_components.ex`:

```heex
<%!-- Schedule Section --%>
<div class="space-y-3">
  <p class="text-sm font-semibold text-hero-charcoal">{gettext("Schedule (optional)")}</p>

  <%!-- Meeting Days Checkboxes --%>
  <fieldset id="meeting-days-fieldset">
    <legend class="text-sm text-hero-grey-600 mb-2">{gettext("Meeting Days")}</legend>
    <div class="flex flex-wrap gap-2">
      <label
        :for={day <- ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)}
        class={[
          "inline-flex items-center gap-1.5 px-3 py-1.5 border text-sm cursor-pointer",
          Theme.rounded(:lg),
          Theme.transition(:normal),
          "has-[:checked]:bg-hero-yellow has-[:checked]:border-hero-yellow-dark has-[:checked]:font-semibold",
          "border-hero-grey-300 hover:border-hero-grey-400"
        ]}
      >
        <input
          type="checkbox"
          name="program_schema[meeting_days][]"
          value={day}
          checked={day in (Phoenix.HTML.Form.input_value(@form, :meeting_days) || [])}
          class="sr-only"
        />
        {String.slice(day, 0, 3)}
      </label>
    </div>
    <%!-- Hidden input ensures empty array submitted when no days checked --%>
    <input type="hidden" name="program_schema[meeting_days][]" value="" />
  </fieldset>

  <%!-- Time Inputs --%>
  <div class="grid grid-cols-2 gap-4">
    <.input
      field={@form[:meeting_start_time]}
      type="time"
      label={gettext("Start Time")}
    />
    <.input
      field={@form[:meeting_end_time]}
      type="time"
      label={gettext("End Time")}
    />
  </div>

  <%!-- Date Inputs --%>
  <div class="grid grid-cols-2 gap-4">
    <.input
      field={@form[:start_date]}
      type="date"
      label={gettext("Start Date")}
    />
    <.input
      field={@form[:end_date]}
      type="date"
      label={gettext("End Date")}
    />
  </div>
</div>
```

**Step 2: Update save_program handler in dashboard_live.ex**

In the `attrs` map construction (lines 456-464), add the scheduling fields:

```elixir
attrs =
  %{
    provider_id: provider.id,
    title: params["title"],
    description: params["description"],
    category: params["category"],
    price: parse_decimal(params["price"]),
    location: presence(params["location"]),
    meeting_days: parse_meeting_days(params["meeting_days"]),
    meeting_start_time: parse_time(params["meeting_start_time"]),
    meeting_end_time: parse_time(params["meeting_end_time"]),
    start_date: parse_date(params["start_date"]),
    end_date: parse_date(params["end_date"])
  }
  |> maybe_add_cover_image(cover_result)
```

Add helper functions:

```elixir
defp parse_meeting_days(nil), do: []
defp parse_meeting_days(days) when is_list(days), do: Enum.reject(days, &(&1 == ""))
defp parse_meeting_days(_), do: []

defp parse_time(nil), do: nil
defp parse_time(""), do: nil

defp parse_time(value) when is_binary(value) do
  case Time.from_iso8601(value <> ":00") do
    {:ok, time} -> time
    _ -> nil
  end
end

defp parse_date(nil), do: nil
defp parse_date(""), do: nil

defp parse_date(value) when is_binary(value) do
  case Date.from_iso8601(value) do
    {:ok, date} -> date
    _ -> nil
  end
end
```

**Step 3: Update create_changeset cast fields**

In `program_schema.ex` `create_changeset/2`, add `:meeting_days, :meeting_start_time, :meeting_end_time, :start_date, :end_date` to the cast list.

**Step 4: Run full compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS with zero warnings

**Step 5: Commit**

```
feat: add scheduling fields to provider program form (#146)
```

---

### Task 7: Display — update program cards and detail page

**Files:**
- Modify: `lib/klass_hero_web/components/program_components.ex:410` (schedule display)
- Modify: `lib/klass_hero_web/live/program_detail_live.ex:138` (schedule display)
- Modify: `lib/klass_hero_web/live/sample_fixtures.ex` (update mock data)

**Step 1: Update program_components.ex**

Replace `{@program.schedule}` (line 410) with a presenter-based display. Since program cards use raw maps from sample_fixtures, check both structured and legacy format. Update the template to display formatted schedule from presenter or fall back gracefully.

**Step 2: Update program_detail_live.ex**

Replace `{@program.schedule}` (line 138) with formatted schedule using presenter.

**Step 3: Update sample_fixtures.ex**

Replace `schedule: "Wednesdays 4-6 PM"` etc. with structured fields:
```elixir
meeting_days: ["Wednesday"],
meeting_start_time: ~T[16:00:00],
meeting_end_time: ~T[18:00:00],
```

**Step 4: Run compile + visual check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 5: Commit**

```
feat: update schedule display to use structured fields (#146)
```

---

### Task 8: Events — update program_created, add program_schedule_updated

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/events/program_events.ex`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/create_program.ex:31-38`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/update_program.ex`
- Modify: `test/klass_hero/program_catalog/domain/events/program_events_test.exs`

**Step 1: Write failing tests for new event**

Add test for `program_schedule_updated/3` event factory.

**Step 2: Add program_schedule_updated to ProgramEvents**

```elixir
def program_schedule_updated(program_id, payload \\ %{}, opts \\ [])

def program_schedule_updated(program_id, payload, opts)
    when is_binary(program_id) and byte_size(program_id) > 0 do
  base_payload = %{program_id: program_id}

  DomainEvent.new(
    :program_schedule_updated,
    program_id,
    @aggregate_type,
    Map.merge(payload, base_payload),
    opts
  )
end
```

**Step 3: Update CreateProgram dispatch_event**

Add scheduling fields to the event payload:
```elixir
event =
  ProgramEvents.program_created(program.id, %{
    provider_id: program.provider_id,
    title: program.title,
    category: program.category,
    instructor_id: program.instructor && program.instructor.id,
    meeting_days: program.meeting_days,
    meeting_start_time: program.meeting_start_time,
    meeting_end_time: program.meeting_end_time,
    start_date: program.start_date,
    end_date: program.end_date
  })
```

**Step 4: Add event dispatch to UpdateProgram**

After successful update, check if scheduling fields changed and dispatch event:

```elixir
@scheduling_fields ~w(meeting_days meeting_start_time meeting_end_time start_date end_date)a

defp maybe_dispatch_schedule_event(original, updated) do
  changed? =
    Enum.any?(@scheduling_fields, fn field ->
      Map.get(original, field) != Map.get(updated, field)
    end)

  if changed? do
    event =
      ProgramEvents.program_schedule_updated(updated.id, %{
        provider_id: updated.provider_id,
        meeting_days: updated.meeting_days,
        meeting_start_time: updated.meeting_start_time,
        meeting_end_time: updated.meeting_end_time,
        start_date: updated.start_date,
        end_date: updated.end_date
      })

    case DomainEventBus.dispatch(KlassHero.ProgramCatalog, event) do
      :ok -> :ok
      {:error, failures} ->
        Logger.warning("[UpdateProgram] Schedule event dispatch had failures",
          program_id: updated.id,
          errors: inspect(failures)
        )
    end
  end
end
```

**Step 5: Run tests**

Run: `mix test test/klass_hero/program_catalog/domain/events/program_events_test.exs`
Expected: All PASS

**Step 6: Commit**

```
feat: add program_schedule_updated event (#146)
```

---

### Task 9: Factory & test fixture cleanup

**Files:**
- Modify: `test/support/factory.ex:69-200` (all program factories)

**Step 1: Update program_factory**

Replace `schedule: "Mon-Fri 3-5pm"` with:
```elixir
meeting_days: ["Monday", "Wednesday", "Friday"],
meeting_start_time: ~T[15:00:00],
meeting_end_time: ~T[17:00:00],
start_date: nil,
```

**Step 2: Update program_schema_factory**

Same replacements for the schema factory.

**Step 3: Update all variant factories** (soccer, dance, yoga, basketball, art)

Replace `schedule` string with structured fields.

**Step 4: Run full test suite**

Run: `mix test`
Expected: All PASS

**Step 5: Commit**

```
feat: update test factories for scheduling fields (#146)
```

---

### Task 10: Full validation — precommit

**Step 1: Run precommit**

Run: `mix precommit`
Expected: Compile (0 warnings), format (clean), test (all pass)

**Step 2: Fix any remaining issues**

If failures, fix and re-run.

**Step 3: Final commit if needed**

```
chore: fix remaining scheduling field references (#146)
```
