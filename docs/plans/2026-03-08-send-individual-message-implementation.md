# Send Individual Message from Roster — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-row "Send Message" buttons to the roster modal enrolled tab, enabling providers to initiate direct conversations with individual parents.

**Architecture:** Extend roster data to include parent user IDs via a new ACL port (Enrollment → Family), add a message icon column to the enrolled tab component, and wire a LiveView event handler that creates/finds a direct conversation then navigates to the messaging page.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, DDD Ports & Adapters

**Skills:** @superpowers:test-driven-development, @phoenix-liveview, @idiomatic-elixir

---

### Task 1: Family Context — Bulk Parent Lookup

Add `list_by_ids/1` to the parent profile port, repository, and facade so the Enrollment ACL adapter can resolve parent profiles in bulk.

**Files:**
- Modify: `lib/klass_hero/family/domain/ports/for_storing_parent_profiles.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository.ex`
- Modify: `lib/klass_hero/family.ex`
- Test: `test/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository_test.exs`

**Step 1: Write the failing test**

Check if `parent_profile_repository_test.exs` exists. If not, create it. Add:

```elixir
describe "list_by_ids/1" do
  test "returns parent profiles matching the given IDs" do
    parent1 = insert(:parent_profile_schema)
    parent2 = insert(:parent_profile_schema)
    _other = insert(:parent_profile_schema)

    result = ParentProfileRepository.list_by_ids([parent1.id, parent2.id])

    ids = Enum.map(result, & &1.id) |> Enum.sort()
    assert ids == Enum.sort([to_string(parent1.id), to_string(parent2.id)])
  end

  test "returns empty list for empty input" do
    assert ParentProfileRepository.list_by_ids([]) == []
  end

  test "silently excludes non-existent IDs" do
    parent = insert(:parent_profile_schema)

    result = ParentProfileRepository.list_by_ids([parent.id, Ecto.UUID.generate()])

    assert length(result) == 1
    assert hd(result).id == to_string(parent.id)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository_test.exs --trace`
Expected: Failures — `list_by_ids/1` not defined.

**Step 3: Write minimal implementation**

Add callback to `for_storing_parent_profiles.ex`:

```elixir
@doc """
Retrieves multiple parent profiles by their IDs.

Missing or invalid IDs are silently excluded from the result.
"""
@callback list_by_ids(parent_ids :: [binary()]) :: [term()]
```

Add implementation in `parent_profile_repository.ex` (follow `child_repository.ex` `list_by_ids/1` pattern):

```elixir
@impl true
def list_by_ids([]), do: []

def list_by_ids(parent_ids) when is_list(parent_ids) do
  ParentProfileSchema
  |> where([p], p.id in ^parent_ids)
  |> Repo.all()
  |> MapperHelpers.to_domain_list(ParentProfileMapper)
end
```

Check if `MapperHelpers` is already imported/aliased in this module. If `ParentProfileMapper` uses a different pattern (e.g., direct `Enum.map`), match that instead.

Add facade function in `family.ex`:

```elixir
@doc """
Retrieves multiple parent profiles by their IDs.

Missing or invalid IDs are silently excluded from the result.
"""
def get_parents_by_ids(parent_ids) when is_list(parent_ids) do
  @parent_repository.list_by_ids(parent_ids)
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository_test.exs --trace`
Expected: All pass.

**Step 5: Commit**

```bash
git add lib/klass_hero/family/domain/ports/for_storing_parent_profiles.ex \
        lib/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository.ex \
        lib/klass_hero/family.ex \
        test/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository_test.exs
git commit -m "feat: add bulk parent profile lookup by IDs to Family context"
```

---

### Task 2: ACL Port + Adapter (Enrollment → Family)

Create the `ForResolvingParentInfo` port and its `ParentInfoACL` adapter, then wire in config.

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_resolving_parent_info.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/acl/parent_info_acl.ex`
- Modify: `config/config.exs`
- Test: `test/klass_hero/enrollment/adapters/driven/acl/parent_info_acl_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ParentInfoACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.ACL.ParentInfoACL

  describe "get_parents_by_ids/1" do
    test "returns parent info maps with id and identity_id" do
      parent = insert(:parent_profile_schema)

      [result] = ParentInfoACL.get_parents_by_ids([parent.id])

      assert result.id == to_string(parent.id)
      assert result.identity_id == to_string(parent.identity_id)
    end

    test "returns empty list for empty input" do
      assert ParentInfoACL.get_parents_by_ids([]) == []
    end

    test "returns only id and identity_id fields" do
      parent = insert(:parent_profile_schema)

      [result] = ParentInfoACL.get_parents_by_ids([parent.id])

      assert Map.keys(result) |> Enum.sort() == [:id, :identity_id]
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/acl/parent_info_acl_test.exs --trace`
Expected: Module not found.

**Step 3: Write minimal implementation**

Create port `for_resolving_parent_info.ex`:

```elixir
defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingParentInfo do
  @moduledoc """
  ACL port for resolving parent identity data from outside the Enrollment context.

  Enrollment needs parent user IDs to enable direct messaging from the roster.
  This port abstracts the source of that data (Family context) behind a simple contract.

  Returns only the fields Enrollment cares about — profile id and user account id —
  never exposing Family domain types to the Enrollment context.
  """

  @type parent_info :: %{
          id: String.t(),
          identity_id: String.t()
        }

  @callback get_parents_by_ids(parent_ids :: [String.t()]) :: [parent_info()]
end
```

Create adapter `parent_info_acl.ex`:

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ParentInfoACL do
  @moduledoc """
  ACL adapter that translates Family context parent data into
  Enrollment's parent info representation.

  The Enrollment context never directly depends on Family domain models.
  This adapter queries the Family facade and maps only the fields
  needed for roster messaging into plain maps.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForResolvingParentInfo

  alias KlassHero.Family

  @impl true
  def get_parents_by_ids([]), do: []

  def get_parents_by_ids(parent_ids) when is_list(parent_ids) do
    parent_ids
    |> Family.get_parents_by_ids()
    |> Enum.map(fn parent ->
      %{
        id: parent.id,
        identity_id: parent.identity_id
      }
    end)
  end
end
```

Wire in `config/config.exs` under `:enrollment` config, near `for_resolving_child_info`:

```elixir
for_resolving_parent_info: KlassHero.Enrollment.Adapters.Driven.ACL.ParentInfoACL,
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/acl/parent_info_acl_test.exs --trace`
Expected: All pass.

**Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_resolving_parent_info.ex \
        lib/klass_hero/enrollment/adapters/driven/acl/parent_info_acl.ex \
        config/config.exs \
        test/klass_hero/enrollment/adapters/driven/acl/parent_info_acl_test.exs
git commit -m "feat: add ForResolvingParentInfo ACL port and adapter"
```

---

### Task 3: Extend `ListProgramEnrollments` with Parent Data

**Files:**
- Modify: `lib/klass_hero/enrollment/application/use_cases/list_program_enrollments.ex`
- Modify: `test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs`

**Step 1: Write failing tests**

Add to the existing `describe "execute/1"` block:

```elixir
test "includes parent_id and parent_user_id in roster entries" do
  program = insert(:program_schema)
  {child, parent} = insert_child_with_guardian(first_name: "Emma", last_name: "Smith")

  insert(:enrollment_schema,
    program_id: program.id,
    child_id: child.id,
    parent_id: parent.id,
    status: "confirmed"
  )

  [entry] = ListProgramEnrollments.execute(program.id)

  assert entry.parent_id == to_string(parent.id)
  assert entry.parent_user_id == to_string(parent.identity_id)
end

test "returns nil parent_user_id when parent profile not found" do
  program = insert(:program_schema)
  {child, _parent} = insert_child_with_guardian(first_name: "Orphan", last_name: "Entry")

  fake_parent_id = Ecto.UUID.generate()

  insert(:enrollment_schema,
    program_id: program.id,
    child_id: child.id,
    parent_id: fake_parent_id,
    status: "confirmed"
  )

  [entry] = ListProgramEnrollments.execute(program.id)

  assert entry.parent_id == fake_parent_id
  assert entry.parent_user_id == nil
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs --trace`
Expected: 2 new failures — keys `parent_id` and `parent_user_id` not present.

**Step 3: Write minimal implementation**

In `list_program_enrollments.ex`:

Add module attribute:

```elixir
@parent_info_adapter Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_resolving_parent_info
                     ])
```

Update `@type roster_entry`:

```elixir
@type roster_entry :: %{
        enrollment_id: String.t(),
        child_id: String.t(),
        child_name: String.t(),
        parent_id: String.t(),
        parent_user_id: String.t() | nil,
        status: atom(),
        enrolled_at: DateTime.t()
      }
```

Update `execute/1` — add parent resolution after child resolution:

```elixir
parent_ids = enrollments |> Enum.map(& &1.parent_id) |> Enum.uniq()
parents = @parent_info_adapter.get_parents_by_ids(parent_ids)
parent_map = Map.new(parents, fn p -> {p.id, p} end)

Enum.map(enrollments, &build_roster_entry(&1, child_map, parent_map))
```

Update `build_roster_entry/2` → `build_roster_entry/3`:

```elixir
defp build_roster_entry(enrollment, child_map, parent_map) do
  child_name =
    case Map.get(child_map, enrollment.child_id) do
      nil -> "Unknown"
      child -> "#{child.first_name} #{child.last_name}"
    end

  # Trigger: parent profile might not exist (deleted, orphaned enrollment)
  # Why: graceful degradation — roster still displays, messaging button disabled
  # Outcome: nil parent_user_id causes the message button to be disabled in UI
  parent_user_id =
    case Map.get(parent_map, enrollment.parent_id) do
      nil -> nil
      parent -> parent.identity_id
    end

  %{
    enrollment_id: enrollment.id,
    child_id: enrollment.child_id,
    child_name: child_name,
    parent_id: enrollment.parent_id,
    parent_user_id: parent_user_id,
    status: enrollment.status,
    enrolled_at: enrollment.enrolled_at
  }
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs --trace`
Expected: All pass (including the existing tests).

**Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/application/use_cases/list_program_enrollments.ex \
        test/klass_hero/enrollment/application/use_cases/list_program_enrollments_test.exs
git commit -m "feat: include parent_id and parent_user_id in roster entries"
```

---

### Task 4: Add Message Column to Component + Wire LiveView

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write failing LiveView tests**

Add to `dashboard_live_test.exs`:

```elixir
describe "roster send message button" do
  setup %{provider: provider} do
    program =
      insert_program_with_listing(
        provider_id: provider.id,
        title: "Message Test Program"
      )

    %{program: program}
  end

  test "shows enabled message button for confirmed enrollment", %{
    conn: conn,
    program: program
  } do
    parent = KlassHero.Factory.insert(:parent_profile_schema)
    child = KlassHero.Factory.insert(:child_schema)

    enrollment =
      KlassHero.Factory.insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
    view |> element("#view-roster-#{program.id}") |> render_click()

    assert has_element?(view, "#send-message-#{enrollment.id}")
    refute has_element?(view, "#send-message-#{enrollment.id}[disabled]")
  end

  test "shows disabled message button for pending enrollment", %{
    conn: conn,
    program: program
  } do
    parent = KlassHero.Factory.insert(:parent_profile_schema)
    child = KlassHero.Factory.insert(:child_schema)

    enrollment =
      KlassHero.Factory.insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
    view |> element("#view-roster-#{program.id}") |> render_click()

    assert has_element?(view, "#send-message-#{enrollment.id}[disabled]")
  end

  test "clicking send message navigates to messaging page", %{
    conn: conn,
    program: program
  } do
    parent = KlassHero.Factory.insert(:parent_profile_schema)
    child = KlassHero.Factory.insert(:child_schema)

    enrollment =
      KlassHero.Factory.insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
    view |> element("#view-roster-#{program.id}") |> render_click()

    view |> element("#send-message-#{enrollment.id}") |> render_click()

    assert_redirect(view, ~r"/provider/messages/")
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --trace --max-failures 3`
Expected: Failures — no `#send-message-*` element found.

**Step 3: Implement component changes**

In `provider_components.ex`:

Add `can_message?` attr to `roster_modal` (near the other attrs around line 1369-1381):

```elixir
attr :can_message?, :boolean, default: false
```

Pass it down in the `roster_modal` template:

```heex
<.enrolled_tab entries={@entries} can_message?={@can_message?} />
```

Add attr to `enrolled_tab` (before `defp enrolled_tab`):

```elixir
attr :can_message?, :boolean, default: false
```

Add 4th column header in `<thead>`:

```heex
<th class="px-3 py-2 text-right text-xs font-semibold text-hero-grey-500 uppercase">
  <span class="sr-only">{gettext("Actions")}</span>
</th>
```

Add message button cell in each `<tr>`, after the enrolled_at `<td>`:

```heex
<td class="px-3 py-3 text-right">
  <%= if @can_message? and entry.status == :confirmed and entry.parent_user_id do %>
    <button
      id={"send-message-#{entry.enrollment_id}"}
      type="button"
      phx-click="send_message_to_parent"
      phx-value-parent-user-id={entry.parent_user_id}
      title={gettext("Send Message")}
      aria-label={gettext("Send Message")}
      class={[
        "p-2 inline-flex",
        Theme.rounded(:lg),
        Theme.transition(:normal),
        "text-hero-grey-400 hover:text-hero-charcoal hover:bg-hero-grey-100"
      ]}
    >
      <.icon name="hero-chat-bubble-left-mini" class="w-5 h-5" />
    </button>
  <% else %>
    <button
      id={"send-message-#{entry.enrollment_id}"}
      type="button"
      disabled
      title={message_button_title(@can_message?, entry)}
      aria-label={message_button_title(@can_message?, entry)}
      class={[
        "p-2 inline-flex",
        Theme.rounded(:lg),
        "text-hero-grey-300 cursor-not-allowed"
      ]}
    >
      <.icon name="hero-chat-bubble-left-mini" class="w-5 h-5" />
    </button>
  <% end %>
</td>
```

Add helper function:

```elixir
defp message_button_title(false = _can_message?, _entry),
  do: gettext("Upgrade to Professional to message parents")

defp message_button_title(true = _can_message?, entry) do
  cond do
    entry.parent_user_id == nil -> gettext("Parent account not available")
    entry.status != :confirmed -> gettext("Enrollment not confirmed")
    true -> gettext("Send Message")
  end
end
```

**Step 4: Implement LiveView changes**

In `dashboard_live.ex`:

Add aliases (if not already present):

```elixir
alias KlassHero.Entitlements
alias KlassHero.Messaging
```

Add `can_message?: false` to the roster assigns block in `mount` (around line 86-94).

Add `can_message?: false` to `close_roster` handler assigns.

In `view_roster` handler, add to the assign block:

```elixir
can_message?: Entitlements.can_initiate_messaging?(socket.assigns.current_scope)
```

Pass `can_message?` in the `programs_section` template's `roster_modal` call:

```heex
can_message?={@can_message?}
```

Add the `can_message?` attr to `programs_section` defp (around line 1300):

```elixir
attr :can_message?, :boolean, default: false
```

Add `send_message_to_parent` event handler:

```elixir
@impl true
def handle_event("send_message_to_parent", %{"parent-user-id" => parent_user_id}, socket) do
  scope = socket.assigns.current_scope
  provider_id = scope.provider.id

  case Messaging.create_direct_conversation(scope, provider_id, parent_user_id) do
    {:ok, conversation} ->
      {:noreply, push_navigate(socket, to: ~p"/provider/messages/#{conversation.id}")}

    {:error, :not_entitled} ->
      {:noreply, put_flash(socket, :error, gettext("Upgrade your plan to send messages."))}

    {:error, _reason} ->
      {:noreply,
       put_flash(socket, :error, gettext("Could not start conversation. Please try again."))}
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --trace`
Expected: All pass (including existing tests).

**Step 6: Commit**

```bash
git add lib/klass_hero_web/components/provider_components.ex \
        lib/klass_hero_web/live/provider/dashboard_live.ex \
        test/klass_hero_web/live/provider/dashboard_live_test.exs
git commit -m "feat: add send message button to roster with entitlement gating"
```

---

### Task 5: Final Verification

**Step 1: Run full pre-commit checks**

Run: `mix precommit`
Expected: All tests pass, no warnings, code formatted.

**Step 2: Fix any issues found**

Address warnings or failures if any.

**Step 3: Commit fixes if needed**

---

### Task 6: Push and Create PR

**Step 1: Push branch**

```bash
git push -u origin worktree-feat/318-send-individual-message
```

**Step 2: Create PR**

Title: `feat: add send individual message button to roster modal`
Reference: Closes #318

Summary should cover:
- New ACL port + adapter for parent profile resolution (Enrollment → Family)
- Extended roster entries with `parent_id` and `parent_user_id`
- Message icon column with disabled states (entitlement tier + enrollment status)
- Event handler creating/finding direct conversations and navigating to messaging page
