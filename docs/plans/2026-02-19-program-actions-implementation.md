# Program Action Buttons Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire up Preview, Edit, and View Roster action buttons on the provider dashboard programs table; remove the Duplicate button.

**Architecture:** Preview = navigation link. Edit = reuse existing modal + UpdateProgram use case. View Roster = new ACL port + adapter + use case in Enrollment context, new modal component. Duplicate = delete from template.

**Tech Stack:** Elixir/Phoenix LiveView, DDD Ports & Adapters, Ecto, TDD

---

## Task 1: Remove Duplicate Button & Wire Preview Link

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex:1293-1299`

**Step 1: Update the action buttons in the programs table**

Replace lines 1293-1299 in `provider_components.ex`:

```elixir
# Current (dead buttons):
<.action_button icon="hero-eye-mini" title={gettext("Preview")} />
<.action_button icon="hero-user-group-mini" title={gettext("View Roster")} />
<.action_button icon="hero-pencil-square-mini" title={gettext("Edit")} />
<.action_button icon="hero-document-duplicate-mini" title={gettext("Duplicate")} />
```

Replace with:

```elixir
<.link navigate={~p"/programs/#{program.id}"} class="inline-block">
  <.action_button icon="hero-eye-mini" title={gettext("Preview")} />
</.link>
<.action_button
  icon="hero-user-group-mini"
  title={gettext("View Roster")}
  phx-click="view_roster"
  phx-value-id={program.id}
/>
<.action_button
  icon="hero-pencil-square-mini"
  title={gettext("Edit")}
  phx-click="edit_program"
  phx-value-id={program.id}
/>
```

Duplicate button is deleted entirely.

**Step 2: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS (no warnings)

**Step 3: Commit**

```bash
git add lib/klass_hero_web/components/provider_components.ex
git commit -m "feat: wire Preview link, remove Duplicate button (#145)"
```

---

## Task 2: Wire Edit Button — Event Handler + Modal Reuse

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`

**Step 1: Add `editing_program_id` assign in mount**

In `mount/3` (around line 89), after `assign(show_program_form: false)`, add:

```elixir
|> assign(editing_program_id: nil)
```

**Step 2: Add `edit_program` event handler**

After the `handle_event("add_program", ...)` block (after line 445), add:

```elixir
@impl true
def handle_event("edit_program", %{"id" => program_id}, socket) do
  case ProgramCatalog.get_program_by_id(program_id) do
    {:ok, program} ->
      # Trigger: pre-populate the form with existing program data
      # Why: reuse the same program_form component for both create and edit
      # Outcome: form opens with current values, submit handler checks editing_program_id
      program_params = %{
        "title" => program.title,
        "description" => program.description,
        "category" => program.category,
        "price" => program.price && Decimal.to_string(program.price),
        "location" => program.location,
        "instructor_id" => program.instructor && program.instructor.id,
        "meeting_days" => program.meeting_days || [],
        "meeting_start_time" => program.meeting_start_time && Time.to_iso8601(program.meeting_start_time),
        "meeting_end_time" => program.meeting_end_time && Time.to_iso8601(program.meeting_end_time),
        "start_date" => program.start_date && Date.to_iso8601(program.start_date),
        "end_date" => program.end_date && Date.to_iso8601(program.end_date),
        "registration_start_date" => program.registration_start_date && Date.to_iso8601(program.registration_start_date),
        "registration_end_date" => program.registration_end_date && Date.to_iso8601(program.registration_end_date)
      }

      changeset = ProgramCatalog.new_program_changeset(program_params)

      # Also load existing enrollment policy for this program
      enrollment_form = load_enrollment_policy_form(program_id)
      participant_policy_form = load_participant_policy_form(program_id)

      {:noreply,
       socket
       |> assign(
         show_program_form: true,
         editing_program_id: program_id,
         program_form: to_form(changeset),
         enrollment_form: enrollment_form,
         participant_policy_form: participant_policy_form,
         instructor_options: build_instructor_options(socket.assigns.current_scope.provider.id)
       )}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, gettext("Program not found."))}
  end
end
```

**Step 3: Add enrollment/participant policy form loaders**

Add private helpers at the bottom of the module (before the final `end`):

```elixir
defp load_enrollment_policy_form(program_id) do
  case Enrollment.get_enrollment_policy(program_id) do
    {:ok, policy} ->
      to_form(
        Enrollment.new_policy_changeset(%{
          "min_enrollment" => policy.min_enrollment && to_string(policy.min_enrollment),
          "max_enrollment" => policy.max_enrollment && to_string(policy.max_enrollment)
        }),
        as: "enrollment_policy"
      )

    {:error, :not_found} ->
      to_form(Enrollment.new_policy_changeset(), as: "enrollment_policy")
  end
end

defp load_participant_policy_form(program_id) do
  case Enrollment.get_participant_policy(program_id) do
    {:ok, policy} ->
      to_form(
        Enrollment.new_participant_policy_changeset(%{
          "min_age_months" => policy.min_age_months && to_string(policy.min_age_months),
          "max_age_months" => policy.max_age_months && to_string(policy.max_age_months),
          "min_grade" => policy.min_grade && to_string(policy.min_grade),
          "max_grade" => policy.max_grade && to_string(policy.max_grade),
          "allowed_genders" => policy.allowed_genders || [],
          "eligibility_at" => policy.eligibility_at
        }),
        as: "participant_policy"
      )

    {:error, :not_found} ->
      to_form(Enrollment.new_participant_policy_changeset(), as: "participant_policy")
  end
end
```

**Step 4: Reset `editing_program_id` in `add_program` handler**

In the existing `handle_event("add_program", ...)` (line 430-445), add `editing_program_id: nil` to the assign:

```elixir
|> assign(show_program_form: true, editing_program_id: nil)
```

**Step 5: Reset `editing_program_id` in `close_program_form` handler**

In the existing `handle_event("close_program_form", ...)` (line 448-456), add:

```elixir
editing_program_id: nil,
```

**Step 6: Update `save_program` handler to branch on edit vs create**

In `handle_event("save_program", ...)` (line 488), after `maybe_add_cover_image(cover_result)`, replace the `with` block to branch:

```elixir
case socket.assigns.editing_program_id do
  nil ->
    # CREATE flow (existing logic)
    create_program(socket, attrs, all_params)

  program_id ->
    # EDIT flow — delegate to UpdateProgram use case
    update_program(socket, program_id, attrs, all_params)
end
```

Extract the existing create logic into `create_program/3` and add a new `update_program/4`:

```elixir
defp update_program(socket, program_id, attrs, all_params) do
  # Trigger: instructor_id may have changed
  # Why: UpdateProgram expects instructor as embedded map, same as create
  # Outcome: enriched attrs passed to ProgramCatalog.update_program
  program_params = all_params["program_schema"] || %{}

  with {:ok, attrs} <- maybe_add_instructor(attrs, program_params["instructor_id"], socket),
       {:ok, updated} <- ProgramCatalog.update_program(program_id, attrs) do
    enrollment_params = all_params["enrollment_policy"] || %{}
    policy_result = maybe_set_enrollment_policy(program_id, enrollment_params)

    participant_policy_params = all_params["participant_policy"] || %{}
    maybe_set_participant_policy(program_id, participant_policy_params)

    capacity = resolve_capacity(policy_result, enrollment_params)
    enrollment_data = %{program_id => %{enrolled: nil, capacity: capacity}}
    view = ProgramPresenter.to_table_view(updated, enrollment_data)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Program updated successfully."))
     |> stream_insert(:programs, view)
     |> assign(show_program_form: false, editing_program_id: nil)}
  else
    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, gettext("Program not found."))}

    {:error, :stale_data} ->
      {:noreply,
       put_flash(
         socket,
         :error,
         gettext("This program was modified by someone else. Please close and try again.")
       )}

    {:error, :instructor_not_found} ->
      {:noreply,
       put_flash(socket, :error, gettext("Selected instructor could not be found. Please try again."))}

    {:error, errors} when is_list(errors) ->
      {:noreply, put_flash(socket, :error, Enum.join(errors, ", "))}

    {:error, changeset} ->
      {:noreply,
       socket
       |> assign(program_form: to_form(Map.put(changeset, :action, :validate)))
       |> put_flash(:error, gettext("Please fix the errors below."))}
  end
end
```

**Step 7: Pass `editing` flag to `programs_section`/`program_form`**

In `programs_section/1` (line 998-1020), pass `editing={@editing_program_id != nil}` to `.program_form`:

```elixir
<.program_form
  form={@program_form}
  enrollment_form={@enrollment_form}
  participant_policy_form={@participant_policy_form}
  uploads={@uploads}
  instructor_options={@instructor_options}
  categories={@categories}
  editing={@editing_program_id != nil}
/>
```

Also add the `editing_program_id` attr to `programs_section`:

```elixir
attr :editing_program_id, :string, default: nil
```

And pass it from `render/1` (line 731-743):

```elixir
<.programs_section
  ...
  editing_program_id={@editing_program_id}
/>
```

**Step 8: Update `validate_program` handler to support edit mode**

In the existing `handle_event("validate_program", ...)` (line 458-485), the changeset creation needs to use the existing program data for edit mode. Replace:

```elixir
changeset =
  ProgramCatalog.new_program_changeset(program_params)
  |> Map.put(:action, :validate)
```

With:

```elixir
changeset =
  ProgramCatalog.new_program_changeset(program_params)
  |> Map.put(:action, :validate)
```

Actually — the existing code already works. `new_program_changeset(params)` creates a changeset from params regardless of whether it's a new or existing program. The changeset will validate and show errors the same way. No change needed here.

**Step 9: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 10: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "feat: wire Edit button with modal reuse (#145)"
```

---

## Task 3: View Roster — ACL Port (Enrollment Domain Layer)

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_resolving_child_info.ex`

**Step 1: Write the ACL port behaviour**

Follow the pattern from `ForResolvingParticipantDetails` (same directory):

```elixir
defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingChildInfo do
  @moduledoc """
  ACL port for resolving child identity data from outside the Enrollment context.

  Enrollment needs child names to display program rosters. This port abstracts
  the source of that data (Family context) behind a simple contract.

  Returns only the fields Enrollment cares about — id and display name —
  never exposing Family domain types to the Enrollment context.
  """

  @type child_info :: %{
          id: String.t(),
          first_name: String.t(),
          last_name: String.t()
        }

  @callback get_children_by_ids(child_ids :: [String.t()]) :: [child_info()]
end
```

**Step 2: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_resolving_child_info.ex
git commit -m "feat: add ForResolvingChildInfo ACL port (#145)"
```

---

## Task 4: View Roster — ACL Adapter (Enrollment Adapter Layer)

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/acl/child_info_acl.ex`
- Modify: `config/config.exs` (add DI config)

**Step 1: Write the ACL adapter**

Follow the pattern from `ParticipantDetailsACL`:

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ChildInfoACL do
  @moduledoc """
  ACL adapter that translates Family context child data into
  Enrollment's child info representation.

  The Enrollment context never directly depends on Family domain models.
  This adapter queries the Family facade and maps only the fields
  needed for roster display into plain maps.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForResolvingChildInfo

  alias KlassHero.Family

  @impl true
  def get_children_by_ids([]), do: []

  def get_children_by_ids(child_ids) when is_list(child_ids) do
    child_ids
    |> Family.get_children_by_ids()
    |> Enum.map(fn child ->
      %{
        id: child.id,
        first_name: child.first_name,
        last_name: child.last_name
      }
    end)
  end
end
```

**Step 2: Add DI config in `config/config.exs`**

In the enrollment config block (line 68-77), add the new ACL:

```elixir
config :klass_hero, :enrollment,
  for_managing_enrollments:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository,
  for_managing_enrollment_policies:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository,
  for_managing_participant_policies:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.ParticipantPolicyRepository,
  for_resolving_participant_details:
    KlassHero.Enrollment.Adapters.Driven.ACL.ParticipantDetailsACL,
  for_resolving_program_schedule: KlassHero.Enrollment.Adapters.Driven.ACL.ProgramScheduleACL,
  for_resolving_child_info: KlassHero.Enrollment.Adapters.Driven.ACL.ChildInfoACL
```

**Step 3: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driven/acl/child_info_acl.ex config/config.exs
git commit -m "feat: add ChildInfoACL adapter with DI config (#145)"
```

---

## Task 5: View Roster — Repository Method + Port Callback

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs`

**Step 1: Write the failing test**

Create or modify the enrollment repository test to add:

```elixir
describe "list_by_program/1" do
  test "returns active enrollments for a program" do
    # Setup: create users, parent, children, provider, program, enrollments
    user = KlassHero.AccountsFixtures.user_fixture()
    parent = KlassHero.FamilyFixtures.parent_profile_fixture(%{identity_id: user.id})
    child = KlassHero.FamilyFixtures.child_fixture(%{parent_id: parent.id})
    provider = KlassHero.ProviderFixtures.provider_profile_fixture()
    program = KlassHero.ProgramCatalogFixtures.program_fixture(%{provider_id: provider.id})

    {:ok, enrollment} =
      KlassHero.Enrollment.create_enrollment(%{
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        subtotal: Decimal.new("0"),
        vat_amount: Decimal.new("0"),
        total_amount: Decimal.new("0"),
        payment_method: "card"
      })

    result = EnrollmentRepository.list_by_program(program.id)

    assert length(result) == 1
    assert hd(result).id == enrollment.id
    assert hd(result).child_id == child.id
  end

  test "excludes cancelled enrollments" do
    # Similar setup, but cancel the enrollment after creation
    # Then verify list_by_program returns empty list
  end

  test "returns empty list when no enrollments exist" do
    assert [] == EnrollmentRepository.list_by_program(Ecto.UUID.generate())
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs --max-failures 1`
Expected: FAIL — `list_by_program/1` undefined

**Step 3: Add port callback**

In `for_managing_enrollments.ex`, add after `enrolled?/2` callback (line 100):

```elixir
@doc """
Lists active enrollments for a program.

Active enrollments are those with status "pending" or "confirmed".
Returns list of Enrollment.t(), ordered by enrolled_at descending.
"""
@callback list_by_program(program_id :: binary()) :: [Enrollment.t()]
```

**Step 4: Implement repository method**

In `enrollment_repository.ex`, add after `enrolled?/2` (line 219):

```elixir
@impl true
@doc """
Lists active enrollments for a program from the database.

Returns list of Enrollment.t(), ordered by enrolled_at descending.
Returns empty list if no active enrollments found.
"""
def list_by_program(program_id) when is_binary(program_id) do
  EnrollmentQueries.base()
  |> EnrollmentQueries.by_program(program_id)
  |> EnrollmentQueries.active_only()
  |> EnrollmentQueries.order_by_enrolled_at_desc()
  |> Repo.all()
  |> EnrollmentMapper.to_domain_list()
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex \
  lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex \
  test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs
git commit -m "feat: add list_by_program to enrollment repo + port (#145)"
```

---

## Task 6: View Roster — Use Case + Facade

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/list_program_enrollments.ex`
- Modify: `lib/klass_hero/enrollment.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ListProgramEnrollmentsTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Application.UseCases.ListProgramEnrollments

  # Setup: create enrollments + children in the DB via fixtures

  describe "execute/1" do
    test "returns enriched roster entries for a program with enrollments" do
      # Setup: create program, child, enrollment
      user = KlassHero.AccountsFixtures.user_fixture()
      parent = KlassHero.FamilyFixtures.parent_profile_fixture(%{identity_id: user.id})
      child = KlassHero.FamilyFixtures.child_fixture(%{parent_id: parent.id, first_name: "Emma", last_name: "Smith"})
      provider = KlassHero.ProviderFixtures.provider_profile_fixture()
      program = KlassHero.ProgramCatalogFixtures.program_fixture(%{provider_id: provider.id})

      {:ok, _enrollment} =
        KlassHero.Enrollment.create_enrollment(%{
          program_id: program.id,
          child_id: child.id,
          parent_id: parent.id,
          subtotal: Decimal.new("0"),
          vat_amount: Decimal.new("0"),
          total_amount: Decimal.new("0"),
          payment_method: "card"
        })

      result = ListProgramEnrollments.execute(program.id)

      assert length(result) == 1
      entry = hd(result)
      assert entry.child_name == "Emma Smith"
      assert entry.status in [:pending, :confirmed]
      assert %DateTime{} = entry.enrolled_at
    end

    test "returns empty list when no enrollments" do
      assert [] == ListProgramEnrollments.execute(Ecto.UUID.generate())
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs --max-failures 1`
Expected: FAIL — module not found

**Step 3: Implement the use case**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ListProgramEnrollments do
  @moduledoc """
  Lists enriched enrollment roster entries for a program.

  Fetches active enrollments, then resolves child names via the
  ForResolvingChildInfo ACL port. Returns a flat list of roster
  entries with child_name, status, and enrolled_at.
  """

  require Logger

  @type roster_entry :: %{
          enrollment_id: String.t(),
          child_id: String.t(),
          child_name: String.t(),
          status: atom(),
          enrolled_at: DateTime.t()
        }

  @doc """
  Returns enriched roster entries for the given program.

  Each entry contains child_name (resolved via ACL), enrollment status,
  and enrolled_at timestamp.
  """
  @spec execute(binary()) :: [roster_entry()]
  def execute(program_id) when is_binary(program_id) do
    Logger.info("[Enrollment.ListProgramEnrollments] Listing roster", program_id: program_id)

    enrollments = repository().list_by_program(program_id)

    # Trigger: no enrollments exist for this program
    # Why: skip the ACL call entirely when there's nothing to enrich
    # Outcome: return empty list immediately
    if enrollments == [] do
      []
    else
      child_ids = Enum.map(enrollments, & &1.child_id) |> Enum.uniq()
      children = child_info_adapter().get_children_by_ids(child_ids)
      child_map = Map.new(children, fn c -> {c.id, c} end)

      Enum.map(enrollments, fn enrollment ->
        child = Map.get(child_map, enrollment.child_id)

        child_name =
          if child,
            do: "#{child.first_name} #{child.last_name}",
            else: "Unknown"

        %{
          enrollment_id: enrollment.id,
          child_id: enrollment.child_id,
          child_name: child_name,
          status: enrollment.status,
          enrolled_at: enrollment.enrolled_at
        }
      end)
    end
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end

  defp child_info_adapter do
    Application.get_env(:klass_hero, :enrollment)[:for_resolving_child_info]
  end
end
```

**Step 4: Expose via facade**

In `lib/klass_hero/enrollment.ex`, add the alias at the top (around line 53):

```elixir
alias KlassHero.Enrollment.Application.UseCases.ListProgramEnrollments
```

Add the public function after `list_parent_enrollments/1` (around line 103):

```elixir
@doc """
Lists enriched enrollment roster entries for a program.

Returns a list of maps with child_name, enrollment status, and enrolled_at.
Used by the provider dashboard to display the program roster.
"""
def list_program_enrollments(program_id) when is_binary(program_id) do
  ListProgramEnrollments.execute(program_id)
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/application/use_cases/list_program_enrollments.ex \
  lib/klass_hero/enrollment.ex \
  test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs
git commit -m "feat: add ListProgramEnrollments use case with ACL (#145)"
```

---

## Task 7: View Roster — LiveView Handler + Modal Component

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `lib/klass_hero_web/components/provider_components.ex`

**Step 1: Add roster assigns in mount**

In `mount/3`, after the `editing_program_id` assign, add:

```elixir
|> assign(show_roster: false, roster_program_name: nil, roster_entries: [])
```

**Step 2: Add `view_roster` event handler**

In `dashboard_live.ex`, add after the `edit_program` handler:

```elixir
@impl true
def handle_event("view_roster", %{"id" => program_id}, socket) do
  roster = Enrollment.list_program_enrollments(program_id)

  # Trigger: need the program name for the modal title
  # Why: roster modal should display "Roster for [Program Name]"
  # Outcome: find the program name from the current stream or fetch fresh
  program_name =
    case ProgramCatalog.get_program_by_id(program_id) do
      {:ok, program} -> program.title
      {:error, _} -> gettext("Program")
    end

  {:noreply,
   assign(socket,
     show_roster: true,
     roster_program_name: program_name,
     roster_entries: roster
   )}
end

@impl true
def handle_event("close_roster", _params, socket) do
  {:noreply, assign(socket, show_roster: false, roster_entries: [])}
end
```

**Step 3: Add roster modal to programs_section template**

In `programs_section/1` (line 998-1020), add roster modal attrs and render:

Add attrs:
```elixir
attr :show_roster, :boolean, required: true
attr :roster_program_name, :string, default: nil
attr :roster_entries, :list, default: []
```

After `</.programs_table>` in the template, add:

```elixir
<.roster_modal
  :if={@show_roster}
  program_name={@roster_program_name}
  entries={@roster_entries}
/>
```

Pass from `render/1`:
```elixir
<.programs_section
  ...
  show_roster={@show_roster}
  roster_program_name={@roster_program_name}
  roster_entries={@roster_entries}
/>
```

**Step 4: Create `roster_modal` component**

In `provider_components.ex`, add a new component:

```elixir
@doc """
Renders a modal displaying the enrollment roster for a program.
Shows child name, enrollment status, and enrollment date.
"""
attr :program_name, :string, required: true
attr :entries, :list, required: true

def roster_modal(assigns) do
  ~H"""
  <div class="fixed inset-0 z-50 overflow-y-auto" role="dialog" aria-modal="true">
    <div class="flex min-h-screen items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_roster"></div>
      <div class={[
        "relative bg-white w-full max-w-lg shadow-xl",
        Theme.rounded(:xl)
      ]}>
        <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
          <h3 class="text-lg font-semibold text-hero-charcoal">
            {gettext("Roster: %{name}", name: @program_name)}
          </h3>
          <button
            type="button"
            phx-click="close_roster"
            class="text-hero-grey-400 hover:text-hero-grey-600"
          >
            <.icon name="hero-x-mark-mini" class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4">
          <div :if={@entries == []} class="text-center py-8">
            <.icon name="hero-user-group" class="w-12 h-12 mx-auto text-hero-grey-300 mb-3" />
            <p class="text-hero-grey-500">{gettext("No enrollments yet.")}</p>
          </div>

          <table :if={@entries != []} class="w-full">
            <thead class="bg-hero-grey-50 border-b border-hero-grey-200">
              <tr>
                <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
                  {gettext("Child Name")}
                </th>
                <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
                  {gettext("Status")}
                </th>
                <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
                  {gettext("Enrolled")}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-hero-grey-200">
              <tr :for={entry <- @entries} class="hover:bg-hero-grey-50">
                <td class="px-3 py-3 text-sm text-hero-charcoal font-medium">
                  {entry.child_name}
                </td>
                <td class="px-3 py-3">
                  <.status_pill color={enrollment_status_color(entry.status)}>
                    {enrollment_status_label(entry.status)}
                  </.status_pill>
                </td>
                <td class="px-3 py-3 text-sm text-hero-grey-500">
                  {format_enrollment_date(entry.enrolled_at)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
  """
end

defp enrollment_status_color(:pending), do: "warning"
defp enrollment_status_color(:confirmed), do: "success"
defp enrollment_status_color(_), do: "info"

defp enrollment_status_label(:pending), do: gettext("Pending")
defp enrollment_status_label(:confirmed), do: gettext("Confirmed")
defp enrollment_status_label(status), do: status |> to_string() |> String.capitalize()

defp format_enrollment_date(%DateTime{} = dt) do
  Calendar.strftime(dt, "%b %d, %Y")
end

defp format_enrollment_date(_), do: "—"
```

**Step 5: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex \
  lib/klass_hero_web/components/provider_components.ex
git commit -m "feat: add View Roster modal with enrollment display (#145)"
```

---

## Task 8: Full Integration Test

**Files:**
- Modify/Create: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Run all existing tests**

Run: `mix test`
Expected: All pass

**Step 2: Run `mix precommit`**

Run: `mix precommit`
Expected: PASS (compile warnings-as-errors, format, test)

**Step 3: Manual verification via Playwright**

1. Run seeds: `mix run priv/repo/seeds.exs`
2. Log in as `shane.provider-1@gmail.com` / `password`
3. Navigate to `/provider/dashboard/programs`
4. Click Preview → should navigate to public program detail page
5. Click Edit → should open modal with pre-populated form data
6. Click View Roster → should open modal showing enrolled children (or empty state)
7. Close modals → should close cleanly

**Step 4: Commit any test additions**

```bash
git add test/
git commit -m "test: add integration tests for program action buttons (#145)"
```

---

## Dependencies Between Tasks

```
Task 1 (Preview/Remove Duplicate) — independent
Task 2 (Edit wiring) — independent
Task 3 (ACL Port) → Task 4 (ACL Adapter) → Task 6 (Use Case)
Task 5 (Repo method) → Task 6 (Use Case) → Task 7 (LiveView + Modal)
Task 8 (Integration) — depends on all above
```

Tasks 1, 2 can run in parallel.
Tasks 3, 4, 5 can run in parallel (port, adapter, repo are independent until wired in Task 6).
Task 6 depends on 3+4+5.
Task 7 depends on 6.
Task 8 depends on all.
