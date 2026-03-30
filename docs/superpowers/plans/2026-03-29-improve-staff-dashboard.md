# Improve Staff Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SKILLS:** Use `superpowers:test-driven-development` for TDD workflow and `idiomatic-elixir` for all Elixir code.

**Goal:** Make the staff dashboard functional — assigned programs become clickable with session management (view, start, complete) and participation tracking (check-in, check-out, behavioral notes).

**Architecture:** Three dedicated Staff LiveViews under `lib/klass_hero_web/live/staff/`: enhanced `StaffDashboardLive` (action buttons + roster modal), new `StaffSessionsLive` (date-based session list), new `StaffParticipationLive` (check-in/check-out). All scoped to assigned programs via `staff_member.tags`. No code reuse from provider LiveViews — dedicated, simpler implementations.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Tailwind CSS. Existing participation components (`participation_card`, `roster_list`, `date_selector`) are auto-imported via `use KlassHeroWeb, :live_view`.

**Spec:** `docs/superpowers/specs/2026-03-29-improve-staff-dashboard-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `test/support/conn_case.ex` | Modify | Add `register_and_log_in_staff/1` test helper |
| `lib/klass_hero_web/components/participation_components.ex` | Modify | Add `:staff` to `participation_card` role values |
| `lib/klass_hero_web/router.ex` | Modify | Add staff sessions + participation routes |
| `lib/klass_hero_web/live/staff/staff_dashboard_live.ex` | Modify | Action buttons, roster modal, event handlers |
| `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs` | Modify | Tests for action buttons and roster |
| `lib/klass_hero_web/live/staff/staff_sessions_live.ex` | Create | Date-based session list with start/complete |
| `test/klass_hero_web/live/staff/staff_sessions_live_test.exs` | Create | Session listing and operation tests |
| `lib/klass_hero_web/live/staff/staff_participation_live.ex` | Create | Check-in/check-out participation management |
| `lib/klass_hero_web/live/staff/staff_participation_live.html.heex` | Create | Participation template (roster + actions) |
| `test/klass_hero_web/live/staff/staff_participation_live_test.exs` | Create | Participation operation and auth tests |

---

## Task 1: Test Infrastructure — `register_and_log_in_staff` Helper

**Files:**
- Modify: `test/support/conn_case.ex:183-190` (after `register_and_log_in_parent`)

All staff LiveView tests need a setup helper that creates a staff user, provider, and staff member, then logs in. This mirrors `register_and_log_in_provider/1` but for staff.

- [ ] **Step 1: Write the `register_and_log_in_staff/1` helper**

Add after `register_and_log_in_parent/1` (line 190) in `test/support/conn_case.ex`:

```elixir
@doc """
Setup helper that registers and logs in a staff member.

    setup :register_and_log_in_staff

It stores an updated connection, registered user, provider, staff member, and scope
in the test context. This is useful for tests that require staff-only routes.
"""
def register_and_log_in_staff(%{conn: _conn} = context) do
  user = AccountsFixtures.user_fixture(%{intended_roles: [:staff_provider]})
  provider = KlassHero.Factory.insert(:provider_profile_schema)

  staff =
    KlassHero.ProviderFixtures.staff_member_fixture(%{
      provider_id: provider.id,
      user_id: user.id,
      active: true,
      invitation_status: :accepted,
      tags: ["sports"]
    })

  scope = Scope.for_user(user) |> Scope.resolve_roles()

  %{
    conn: log_in_user(context.conn, user),
    user: user,
    scope: scope,
    provider: provider,
    staff: staff
  }
end
```

- [ ] **Step 2: Verify the helper compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation succeeds with no warnings.

- [ ] **Step 3: Commit**

```bash
git add test/support/conn_case.ex
git commit -m "test: add register_and_log_in_staff setup helper"
```

---

## Task 2: Extend `participation_card` to Accept `:staff` Role

**Files:**
- Modify: `lib/klass_hero_web/components/participation_components.ex:37-39`

The `participation_card` component currently only accepts `values: [:provider, :parent]` for the `:role` attr. Staff sessions will pass `role={:staff}` and should see the same capacity info as providers.

- [ ] **Step 1: Update the role attr values**

In `lib/klass_hero_web/components/participation_components.ex`, change line 39:

```elixir
# Before
    values: [:provider, :parent],

# After
    values: [:provider, :parent, :staff],
```

- [ ] **Step 2: Update the capacity conditional**

On line 73, change the condition from only `:provider` to include `:staff`:

```elixir
# Before
        <%= if @role == :provider && Map.get(@session, :capacity) do %>

# After
        <%= if @role in [:provider, :staff] && Map.get(@session, :capacity) do %>
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compilation succeeds with no warnings.

- [ ] **Step 4: Run existing participation component tests**

Run: `mix test test/klass_hero_web/live/provider/participation_live_test.exs test/klass_hero_web/live/provider/sessions_live_test.exs`
Expected: All existing tests still pass (no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/components/participation_components.ex
git commit -m "feat: extend participation_card component to accept :staff role"
```

---

## Task 3: Add Staff Routes to Router

**Files:**
- Modify: `lib/klass_hero_web/router.ex:137-139`

Add the two new routes under the existing `:require_staff_provider` live_session scope.

- [ ] **Step 1: Add routes**

In `lib/klass_hero_web/router.ex`, replace lines 137-139:

```elixir
# Before
      scope "/staff", Staff do
        live "/dashboard", StaffDashboardLive, :index
      end

# After
      scope "/staff", Staff do
        live "/dashboard", StaffDashboardLive, :index
        live "/sessions", StaffSessionsLive, :index
        live "/participation/:session_id", StaffParticipationLive, :show
      end
```

- [ ] **Step 2: Create stub modules so the router compiles**

Create `lib/klass_hero_web/live/staff/staff_sessions_live.ex`:

```elixir
defmodule KlassHeroWeb.Staff.StaffSessionsLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("My Sessions"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-sessions">
      <h1>{gettext("My Sessions")}</h1>
    </div>
    """
  end
end
```

Create `lib/klass_hero_web/live/staff/staff_participation_live.ex`:

```elixir
defmodule KlassHeroWeb.Staff.StaffParticipationLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Manage Participation"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-participation">
      <h1>{gettext("Manage Participation")}</h1>
    </div>
    """
  end
end
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compilation succeeds with no warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero_web/router.ex lib/klass_hero_web/live/staff/staff_sessions_live.ex lib/klass_hero_web/live/staff/staff_participation_live.ex
git commit -m "feat: add staff sessions and participation routes with stub LiveViews"
```

---

## Task 4: Enhance StaffDashboardLive — Action Buttons + Roster Modal

**Files:**
- Modify: `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`
- Modify: `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`

### Subtask 4a: Write failing tests for action buttons and roster

- [ ] **Step 1: Write tests for program action buttons and roster**

Add to `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`, inside the existing `describe "staff dashboard"` block, after the existing tests:

```elixir
    test "program cards show Sessions and Roster action buttons", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      assert has_element?(view, "#sessions-link-#{program.id}")
      assert has_element?(view, "#roster-btn-#{program.id}")
    end

    test "clicking Roster opens roster modal with enrolled children", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      refute has_element?(view, "#staff-roster-modal")

      view |> element("#roster-btn-#{program.id}") |> render_click()

      assert has_element?(view, "#staff-roster-modal")
      assert has_element?(view, "#staff-roster-modal", program.title)
    end

    test "closing roster modal hides it", %{conn: conn, provider: provider, staff: staff} do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      view |> element("#roster-btn-#{program.id}") |> render_click()
      assert has_element?(view, "#staff-roster-modal")

      view |> element("#close-roster-btn") |> render_click()
      refute has_element?(view, "#staff-roster-modal")
    end

    test "roster button rejects program not in assigned set", %{
      conn: conn,
      provider: _provider
    } do
      other_provider = KlassHero.Factory.insert(:provider_profile_schema)

      other_program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: other_provider.id,
          category: "unrelated"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      view
      |> render_hook("view_roster", %{"id" => other_program.id})

      assert render(view) =~ "Unauthorized"
    end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`
Expected: New tests fail (no `sessions-link-*`, `roster-btn-*`, `staff-roster-modal` elements exist yet).

### Subtask 4b: Implement the dashboard enhancements

- [ ] **Step 3: Update the setup block for test fixtures**

The existing test `setup` creates a staff member without tags. Update `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs` setup to also pass `tags`:

```elixir
    setup %{conn: conn} do
      user = user_fixture(intended_roles: [:staff_provider])
      provider = provider_profile_fixture()

      staff =
        staff_member_fixture(%{
          provider_id: provider.id,
          user_id: user.id,
          active: true,
          invitation_status: :accepted,
          tags: ["sports"]
        })

      conn = log_in_user(conn, user)
      %{conn: conn, user: user, provider: provider, staff: staff}
    end
```

- [ ] **Step 4: Implement the enhanced `StaffDashboardLive`**

Replace the entire `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`:

```elixir
defmodule KlassHeroWeb.Staff.StaffDashboardLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Enrollment
  alias KlassHero.ProgramCatalog
  alias KlassHero.Provider
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member

    case Provider.get_provider_profile(staff_member.provider_id) do
      {:ok, provider} ->
        programs = assigned_programs(staff_member)
        assigned_ids = MapSet.new(programs, & &1.id)

        socket =
          socket
          |> assign(:page_title, gettext("Staff Dashboard"))
          |> assign(:provider, provider)
          |> assign(:staff_member, staff_member)
          |> assign(:assigned_program_ids, assigned_ids)
          |> assign(:programs_empty?, programs == [])
          |> assign(:show_roster, false)
          |> assign(:roster_entries, [])
          |> assign(:roster_program_name, nil)
          |> assign(:roster_program_id, nil)
          |> stream(:programs, programs)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("The business associated with your account could not be found.")
         )
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("view_roster", %{"id" => program_id}, socket) do
    if MapSet.member?(socket.assigns.assigned_program_ids, program_id) do
      case ProgramCatalog.get_program_by_id(program_id) do
        {:ok, program} ->
          roster = Enrollment.list_program_enrollments(program_id)

          {:noreply,
           assign(socket,
             show_roster: true,
             roster_program_name: program.title,
             roster_program_id: program_id,
             roster_entries: roster
           )}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Program not found."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
    end
  end

  @impl true
  def handle_event("close_roster", _params, socket) do
    {:noreply,
     assign(socket,
       show_roster: false,
       roster_entries: [],
       roster_program_name: nil,
       roster_program_id: nil
     )}
  end

  defp assigned_programs(staff_member) do
    all = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)
    if staff_member.tags == [], do: all, else: Enum.filter(all, &(&1.category in staff_member.tags))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-dashboard" class="max-w-4xl mx-auto px-4 py-6">
      <div id="business-name" class="mb-6">
        <h1 class={Theme.typography(:page_title)}>
          {@provider.business_name}
        </h1>
        <p class={Theme.typography(:body)}>
          {gettext("Welcome, %{name}", name: @staff_member.first_name)}
        </p>
      </div>

      <div class="mt-8">
        <h2 class={Theme.typography(:section_title)}>
          {gettext("Assigned Programs")}
        </h2>

        <div :if={@programs_empty?} id="programs-empty-state" class="text-center py-8 text-zinc-500">
          {gettext("No programs assigned yet.")}
        </div>

        <div id="assigned-programs" phx-update="stream" class="mt-4 space-y-4">
          <div
            :for={{dom_id, program} <- @streams.programs}
            id={dom_id}
            class="p-4 bg-white rounded-lg shadow-sm border border-zinc-200"
          >
            <h3 class={Theme.typography(:card_title)}>{program.title}</h3>
            <p :if={program.category} class="text-sm text-zinc-500 mt-1">{program.category}</p>

            <div class="flex gap-2 mt-3">
              <.link
                id={"sessions-link-#{program.id}"}
                navigate={~p"/staff/sessions?program_id=#{program.id}"}
                class={[
                  "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium",
                  "text-hero-blue-600 bg-hero-blue-50 hover:bg-hero-blue-100",
                  "rounded-md transition-colors"
                ]}
              >
                <.icon name="hero-calendar-days-mini" class="w-4 h-4" />
                {gettext("Sessions")}
              </.link>

              <button
                id={"roster-btn-#{program.id}"}
                phx-click="view_roster"
                phx-value-id={program.id}
                class={[
                  "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium",
                  "text-hero-grey-700 bg-hero-grey-100 hover:bg-hero-grey-200",
                  "rounded-md transition-colors"
                ]}
              >
                <.icon name="hero-user-group-mini" class="w-4 h-4" />
                {gettext("Roster")}
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Staff Roster Modal --%>
      <%= if @show_roster do %>
        <div id="staff-roster-backdrop" class="fixed inset-0 z-50 bg-black/50" phx-click="close_roster">
        </div>
        <div
          id="staff-roster-modal"
          class={[
            "fixed inset-x-4 top-[10%] z-50 mx-auto max-w-lg bg-white",
            "rounded-xl shadow-xl max-h-[80vh] overflow-y-auto"
          ]}
        >
          <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
            <h2 class="text-lg font-semibold text-hero-charcoal">
              {gettext("Roster: %{name}", name: @roster_program_name)}
            </h2>
            <button
              id="close-roster-btn"
              phx-click="close_roster"
              class="p-1 text-hero-grey-400 hover:text-hero-grey-600"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div class="p-4">
            <%= if @roster_entries == [] do %>
              <p class="text-center text-hero-grey-500 py-4">
                {gettext("No enrollments yet.")}
              </p>
            <% else %>
              <ul class="divide-y divide-hero-grey-200">
                <%= for entry <- @roster_entries do %>
                  <li class="py-3 flex items-center justify-between">
                    <div>
                      <span class="font-medium text-hero-charcoal">
                        {Map.get(entry, :child_name, gettext("Unknown"))}
                      </span>
                    </div>
                    <span class="text-sm text-hero-grey-500">
                      {Map.get(entry, :status, "")}
                    </span>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 5: Run tests**

Run: `mix test test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`
Expected: All tests pass (existing + new).

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/staff/staff_dashboard_live.ex test/klass_hero_web/live/staff/staff_dashboard_live_test.exs
git commit -m "feat: add action buttons and roster modal to staff dashboard"
```

---

## Task 5: Implement StaffSessionsLive

**Files:**
- Modify: `lib/klass_hero_web/live/staff/staff_sessions_live.ex` (replace stub)
- Create: `test/klass_hero_web/live/staff/staff_sessions_live_test.exs`

### Subtask 5a: Write failing tests

- [ ] **Step 1: Write test file**

Create `test/klass_hero_web/live/staff/staff_sessions_live_test.exs`:

```elixir
defmodule KlassHeroWeb.Staff.StaffSessionsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "authentication and authorization" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/staff/sessions")
      assert path =~ "/users/log-in"
    end

    test "redirects non-staff users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/staff/sessions")
    end
  end

  describe "sessions page" do
    setup :register_and_log_in_staff

    test "renders page title and date selector", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/staff/sessions")

      assert has_element?(view, "#staff-sessions")
      assert has_element?(view, "#date-select")
    end

    test "shows sessions for assigned programs only", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      assigned_program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      unassigned_program =
        insert(:program_schema,
          provider_id: provider.id,
          category: "unrelated_category_xyz"
        )

      insert(:program_session_schema,
        program_id: assigned_program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      insert(:program_session_schema,
        program_id: unassigned_program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/staff/sessions")

      html = render(view)
      assert html =~ assigned_program.title
      refute html =~ unassigned_program.title
    end

    test "filters to specific program via query param", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/staff/sessions?program_id=#{program.id}")

      assert has_element?(view, "button", "Start Session")
    end

    test "shows Start Session button for scheduled sessions", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/staff/sessions")

      assert has_element?(view, "button", "Start Session")
    end

    test "shows Manage Participation link for in_progress sessions", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :in_progress
      )

      {:ok, view, _html} = live(conn, ~p"/staff/sessions")

      assert has_element?(view, "a", "Manage Participation")
    end

    test "start_session transitions session to in_progress", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: :scheduled
        )

      {:ok, view, _html} = live(conn, ~p"/staff/sessions")

      view |> element("button", "Start Session") |> render_click()

      assert render(view) =~ "Session started successfully"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/staff/staff_sessions_live_test.exs`
Expected: Tests fail because the stub LiveView doesn't have sessions logic.

### Subtask 5b: Implement StaffSessionsLive

- [ ] **Step 3: Replace the stub with full implementation**

Replace `lib/klass_hero_web/live/staff/staff_sessions_live.ex`:

```elixir
defmodule KlassHeroWeb.Staff.StaffSessionsLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Participation
  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(params, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member
    provider_id = staff_member.provider_id
    selected_date = Date.utc_today()

    programs = assigned_programs(staff_member)
    assigned_ids = MapSet.new(programs, & &1.id)

    # Optional program_id query param to filter to a single program
    filter_program_id = params["program_id"]

    socket =
      socket
      |> assign(:page_title, gettext("My Sessions"))
      |> assign(:staff_member, staff_member)
      |> assign(:provider_id, provider_id)
      |> assign(:selected_date, selected_date)
      |> assign(:assigned_programs, programs)
      |> assign(:assigned_program_ids, assigned_ids)
      |> assign(:filter_program_id, filter_program_id)
      |> stream(:sessions, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        KlassHero.PubSub,
        "participation:provider:#{provider_id}"
      )
    end

    {:ok, load_sessions(socket)}
  end

  @impl true
  def handle_event("change_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, new_date} ->
        socket =
          socket
          |> assign(:selected_date, new_date)
          |> load_sessions()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid date format"))}
    end
  end

  @impl true
  def handle_event("start_session", %{"session_id" => session_id}, socket) do
    if authorized_session?(socket, session_id) do
      case Participation.start_session(session_id) do
        {:ok, _session} ->
          {:noreply, put_flash(socket, :info, gettext("Session started successfully"))}

        {:error, reason} ->
          Logger.error("[StaffSessionsLive.start_session] Failed",
            session_id: session_id,
            reason: inspect(reason)
          )

          {:noreply,
           put_flash(socket, :error, gettext("Failed to start session: %{reason}", reason: inspect(reason)))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
    end
  end

  @impl true
  def handle_event("complete_session", %{"session_id" => session_id}, socket) do
    if authorized_session?(socket, session_id) do
      case Participation.complete_session(session_id) do
        {:ok, _session} ->
          {:noreply, put_flash(socket, :info, gettext("Session completed successfully"))}

        {:error, reason} ->
          Logger.error("[StaffSessionsLive.complete_session] Failed",
            session_id: session_id,
            reason: inspect(reason)
          )

          {:noreply,
           put_flash(socket, :error, gettext("Failed to complete session: %{reason}", reason: inspect(reason)))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
    end
  end

  # PubSub handlers for real-time session updates
  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: event_type,
           aggregate_id: session_id,
           payload: payload
         }},
        socket
      )
      when event_type in [:session_started, :session_completed, :session_created, :roster_seeded] do
    if event_type == :session_created and
         Map.get(payload, :session_date) != socket.assigns.selected_date do
      {:noreply, socket}
    else
      {:noreply, update_session_in_stream(socket, session_id)}
    end
  end

  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_in,
           payload: %{session_id: session_id}
         }},
        socket
      ) do
    {:noreply, update_session_in_stream(socket, session_id)}
  end

  # Catch-all for unhandled domain events
  @impl true
  def handle_info({:domain_event, _event}, socket) do
    {:noreply, socket}
  end

  # Private helpers

  defp assigned_programs(staff_member) do
    all = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)
    if staff_member.tags == [], do: all, else: Enum.filter(all, &(&1.category in staff_member.tags))
  end

  defp load_sessions(socket) do
    provider_id = socket.assigns.provider_id
    selected_date = socket.assigns.selected_date
    assigned_ids = socket.assigns.assigned_program_ids
    filter_program_id = socket.assigns.filter_program_id

    case Participation.list_provider_sessions(provider_id, selected_date) do
      {:ok, sessions} ->
        filtered =
          sessions
          |> Enum.filter(&MapSet.member?(assigned_ids, &1.program_id))
          |> then(fn sessions ->
            if filter_program_id do
              Enum.filter(sessions, &(&1.program_id == filter_program_id))
            else
              sessions
            end
          end)

        stream(socket, :sessions, filtered, reset: true)

      {:error, reason} ->
        Logger.error("[StaffSessionsLive] Failed to load sessions",
          provider_id: provider_id,
          reason: inspect(reason)
        )

        put_flash(socket, :error, gettext("Failed to load sessions"))
    end
  end

  defp authorized_session?(socket, session_id) do
    case Participation.get_session_with_roster(session_id) do
      {:ok, %{session: session}} ->
        MapSet.member?(socket.assigns.assigned_program_ids, session.program_id)

      _ ->
        false
    end
  end

  defp update_session_in_stream(socket, session_id) do
    case Participation.get_session_with_roster(session_id) do
      {:ok, %{session: session}} ->
        if MapSet.member?(socket.assigns.assigned_program_ids, session.program_id) do
          stream_insert(socket, :sessions, session)
        else
          socket
        end

      {:error, _reason} ->
        socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-sessions" class="max-w-4xl mx-auto p-4 md:p-6">
      <div class="mb-6">
        <.page_header>
          <:title>{gettext("My Sessions")}</:title>
          <:subtitle>{gettext("View and manage your scheduled sessions")}</:subtitle>
        </.page_header>
      </div>

      <div class="mb-6">
        <.date_selector
          id="date-select"
          name="date"
          value={@selected_date}
          label="Select Date:"
          phx_change="change_date"
        />
      </div>

      <div id="sessions" phx-update="stream" class="space-y-4">
        <div :for={{id, session} <- @streams.sessions} id={id}>
          <.participation_card session={session} role={:staff}>
            <:actions>
              <%= cond do %>
                <% session.status == :scheduled -> %>
                  <button
                    phx-click="start_session"
                    phx-value-session_id={session.id}
                    class={[
                      "px-4 py-2 bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700",
                      "focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2",
                      Theme.rounded(:lg),
                      Theme.transition(:normal)
                    ]}
                  >
                    {gettext("Start Session")}
                  </button>
                <% session.status == :in_progress -> %>
                  <.link
                    navigate={~p"/staff/participation/#{session.id}"}
                    class={[
                      "px-4 py-2 bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700",
                      "focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2 text-center",
                      Theme.rounded(:lg),
                      Theme.transition(:normal)
                    ]}
                  >
                    {gettext("Manage Participation")}
                  </.link>
                  <button
                    phx-click="complete_session"
                    phx-value-session_id={session.id}
                    class={[
                      "px-4 py-2 bg-gray-600 text-white font-medium hover:bg-gray-700",
                      "focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2",
                      Theme.rounded(:lg),
                      Theme.transition(:normal)
                    ]}
                  >
                    {gettext("Complete Session")}
                  </button>
                <% session.status == :completed -> %>
                  <.link
                    navigate={~p"/staff/participation/#{session.id}"}
                    class={[
                      "px-4 py-2 bg-gray-100 text-gray-700 font-medium hover:bg-gray-200",
                      "focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 text-center",
                      Theme.rounded(:lg),
                      Theme.transition(:normal)
                    ]}
                  >
                    {gettext("View Participation")}
                  </.link>
                <% true -> %>
                  <span class="text-sm text-gray-500">{gettext("No actions available")}</span>
              <% end %>
            </:actions>
          </.participation_card>
        </div>

        <div id="sessions-empty" class="hidden only:block">
          <div class={[
            "p-8 text-center bg-white border border-gray-200",
            Theme.rounded(:lg),
            Theme.shadow(:md)
          ]}>
            <.icon name="hero-calendar" class="w-16 h-16 mx-auto mb-4 text-gray-400" />
            <h3 class="text-lg font-medium text-gray-900 mb-2">
              {gettext("No sessions scheduled")}
            </h3>
            <p class="text-gray-600">
              {gettext("You have no sessions scheduled for %{date}",
                date: Calendar.strftime(@selected_date, "%B %d, %Y")
              )}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/klass_hero_web/live/staff/staff_sessions_live_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Run full test suite**

Run: `mix test`
Expected: No regressions.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/staff/staff_sessions_live.ex test/klass_hero_web/live/staff/staff_sessions_live_test.exs
git commit -m "feat: implement StaffSessionsLive with date-based session management"
```

---

## Task 6: Implement StaffParticipationLive

**Files:**
- Modify: `lib/klass_hero_web/live/staff/staff_participation_live.ex` (replace stub)
- Create: `lib/klass_hero_web/live/staff/staff_participation_live.html.heex`
- Create: `test/klass_hero_web/live/staff/staff_participation_live_test.exs`

### Subtask 6a: Write failing tests

- [ ] **Step 1: Write test file**

Create `test/klass_hero_web/live/staff/staff_participation_live_test.exs`:

```elixir
defmodule KlassHeroWeb.Staff.StaffParticipationLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "authentication and authorization" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      session_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: path}}} =
               live(conn, ~p"/staff/participation/#{session_id}")

      assert path =~ "/users/log-in"
    end

    test "redirects non-staff users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      session_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/staff/participation/#{session_id}")
    end
  end

  describe "participation page" do
    setup :register_and_log_in_staff

    setup %{provider: provider, staff: staff} do
      program =
        insert(:program_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "general"
        )

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: :in_progress
        )

      parent = insert(:parent_profile_schema)

      {child, _parent} =
        insert_child_with_guardian(
          parent: parent,
          first_name: "Lina",
          last_name: "Schmidt"
        )

      record =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: parent.id,
          status: :registered
        )

      %{program: program, session: session, child: child, record: record}
    end

    test "renders session info and roster", %{conn: conn, session: session} do
      {:ok, view, _html} = live(conn, ~p"/staff/participation/#{session.id}")

      assert has_element?(view, "#staff-participation")
      assert has_element?(view, "div", "Lina")
    end

    test "can check in a child", %{conn: conn, session: session} do
      {:ok, view, _html} = live(conn, ~p"/staff/participation/#{session.id}")

      view |> element("button", "Check In") |> render_click()

      assert render(view) =~ "Child checked in successfully"
    end

    test "redirects when session belongs to unassigned program", %{conn: conn, provider: provider} do
      unassigned_program =
        insert(:program_schema,
          provider_id: provider.id,
          category: "unrelated_category_xyz"
        )

      unassigned_session =
        insert(:program_session_schema,
          program_id: unassigned_program.id,
          session_date: Date.utc_today(),
          status: :in_progress
        )

      assert {:error, {:redirect, %{to: "/staff/sessions"}}} =
               live(conn, ~p"/staff/participation/#{unassigned_session.id}")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/staff/staff_participation_live_test.exs`
Expected: Tests fail because the stub doesn't have participation logic.

### Subtask 6b: Implement StaffParticipationLive

- [ ] **Step 3: Replace the stub with full implementation**

Replace `lib/klass_hero_web/live/staff/staff_participation_live.ex`:

```elixir
defmodule KlassHeroWeb.Staff.StaffParticipationLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Participation
  alias KlassHero.ProgramCatalog

  require Logger

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member
    assigned_ids = assigned_program_ids(staff_member)

    socket =
      socket
      |> assign(:page_title, gettext("Manage Participation"))
      |> assign(:session_id, session_id)
      |> assign(:staff_member, staff_member)
      |> assign(:assigned_program_ids, assigned_ids)
      |> assign(:session, nil)
      |> assign(:participation_records, [])
      |> assign(:checkout_form_expanded, nil)
      |> assign(:checkout_forms, %{})
      |> assign(:note_form_expanded, nil)
      |> assign(:note_forms, %{})
      |> assign(:provider_notes, %{})
      |> assign(:record_note_map, %{})

    case Participation.get_session_with_roster_enriched(session_id) do
      {:ok, session} ->
        if MapSet.member?(assigned_ids, session.program_id) do
          if connected?(socket) do
            Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_in")
            Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_out")

            Phoenix.PubSub.subscribe(
              KlassHero.PubSub,
              "participation_record:participation_marked_absent"
            )

            Phoenix.PubSub.subscribe(
              KlassHero.PubSub,
              "behavioral_note:behavioral_note_submitted"
            )

            Phoenix.PubSub.subscribe(
              KlassHero.PubSub,
              "behavioral_note:behavioral_note_approved"
            )

            Phoenix.PubSub.subscribe(
              KlassHero.PubSub,
              "behavioral_note:behavioral_note_rejected"
            )
          end

          {:ok,
           socket
           |> assign(:session, session)
           |> assign(:participation_records, session.participation_records || [])
           |> load_provider_notes()}
        else
          {:ok,
           socket
           |> put_flash(:error, gettext("You don't have access to this session."))
           |> redirect(to: ~p"/staff/sessions")}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Session not found"))
         |> redirect(to: ~p"/staff/sessions")}

      {:error, reason} ->
        Logger.error("[StaffParticipationLive] Failed to load session",
          session_id: session_id,
          reason: inspect(reason)
        )

        {:ok,
         socket
         |> put_flash(:error, gettext("Failed to load session data"))
         |> redirect(to: ~p"/staff/sessions")}
    end
  end

  @impl true
  def handle_event("check_in", %{"id" => record_id}, socket) do
    record = find_participation_record(socket, record_id)

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Record not found"))}

      record ->
        case Participation.record_check_in(%{
               record_id: record.id,
               checked_in_by: socket.assigns.current_scope.user.id
             }) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Child checked in successfully"))
             |> load_session_data()}

          {:error, reason} ->
            Logger.error("[StaffParticipationLive.check_in] Failed",
              record_id: record_id,
              reason: inspect(reason)
            )

            {:noreply,
             put_flash(socket, :error, gettext("Failed to check in: %{reason}", reason: inspect(reason)))}
        end
    end
  end

  @impl true
  def handle_event("expand_checkout_form", %{"id" => record_id}, socket) do
    {:noreply, expand_form(socket, record_id, "checkout", "notes", "", :checkout_form_expanded, :checkout_forms)}
  end

  @impl true
  def handle_event("cancel_checkout", %{"id" => record_id}, socket) do
    {:noreply, cancel_form(socket, record_id, :checkout_form_expanded, :checkout_forms)}
  end

  @impl true
  def handle_event(
        "update_checkout_notes",
        %{"id" => record_id, "checkout" => %{"notes" => notes}},
        socket
      ) do
    {:noreply, update_form(socket, record_id, notes, "checkout", "notes", :checkout_forms)}
  end

  @impl true
  def handle_event("confirm_checkout", %{"id" => record_id, "checkout" => params}, socket) do
    record = find_participation_record(socket, record_id)
    notes = Map.get(params, "notes")

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Record not found"))}

      record ->
        case Participation.record_check_out(%{
               record_id: record.id,
               checked_out_by: socket.assigns.current_scope.user.id,
               notes: notes
             }) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Child checked out successfully"))
             |> assign(:checkout_form_expanded, nil)
             |> assign(:checkout_forms, Map.delete(socket.assigns.checkout_forms, record_id))
             |> load_session_data()}

          {:error, reason} ->
            Logger.error("[StaffParticipationLive.confirm_checkout] Failed",
              record_id: record_id,
              reason: inspect(reason)
            )

            {:noreply,
             put_flash(socket, :error, gettext("Failed to check out: %{reason}", reason: inspect(reason)))}
        end
    end
  end

  # Behavioral note form handlers

  @impl true
  def handle_event("expand_note_form", %{"id" => record_id}, socket) do
    {:noreply, expand_form(socket, record_id, "note", "content", "", :note_form_expanded, :note_forms)}
  end

  @impl true
  def handle_event("cancel_note", %{"id" => record_id}, socket) do
    {:noreply, cancel_form(socket, record_id, :note_form_expanded, :note_forms)}
  end

  @impl true
  def handle_event(
        "update_note_content",
        %{"id" => record_id, "note" => %{"content" => content}},
        socket
      ) do
    {:noreply, update_form(socket, record_id, content, "note", "content", :note_forms)}
  end

  @impl true
  def handle_event("submit_note", %{"id" => record_id, "note" => params}, socket) do
    content = Map.get(params, "content", "")

    case Participation.submit_behavioral_note(%{
           participation_record_id: record_id,
           provider_id: socket.assigns.staff_member.provider_id,
           content: content
         }) do
      {:ok, _note} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Behavioral note submitted for review"))
         |> assign(:note_form_expanded, nil)
         |> assign(:note_forms, Map.delete(socket.assigns.note_forms, record_id))
         |> load_session_data()}

      {:error, :blank_content} ->
        {:noreply, put_flash(socket, :error, gettext("Note content cannot be blank"))}

      {:error, :duplicate_note} ->
        {:noreply, put_flash(socket, :error, gettext("You already submitted a note for this record"))}

      {:error, reason} ->
        Logger.error("[StaffParticipationLive.submit_note] Failed",
          record_id: record_id,
          reason: inspect(reason)
        )

        {:noreply, put_flash(socket, :error, gettext("Failed to submit note"))}
    end
  end

  # PubSub event handlers
  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: event_type
         }},
        socket
      )
      when event_type in [:child_checked_in, :child_checked_out, :participation_marked_absent] do
    {:noreply, load_session_data(socket)}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: event_type
         }},
        socket
      )
      when event_type in [
             :behavioral_note_submitted,
             :behavioral_note_approved,
             :behavioral_note_rejected
           ] do
    {:noreply, load_session_data(socket)}
  end

  @impl true
  def handle_info({:domain_event, _event}, socket) do
    {:noreply, socket}
  end

  # Form lifecycle helpers

  defp expand_form(socket, id, form_name, field, initial_value, expanded_key, forms_key) do
    form = to_form(%{field => initial_value}, as: form_name)

    socket
    |> assign(expanded_key, id)
    |> assign(forms_key, Map.put(Map.get(socket.assigns, forms_key), id, form))
  end

  defp cancel_form(socket, id, expanded_key, forms_key) do
    socket
    |> assign(expanded_key, nil)
    |> assign(forms_key, Map.delete(Map.get(socket.assigns, forms_key), id))
  end

  defp update_form(socket, id, value, form_name, field, forms_key) do
    updated_form = to_form(%{field => value}, as: form_name)
    assign(socket, forms_key, Map.put(Map.get(socket.assigns, forms_key), id, updated_form))
  end

  # Private helpers

  defp assigned_program_ids(staff_member) do
    all = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)

    programs =
      if staff_member.tags == [],
        do: all,
        else: Enum.filter(all, &(&1.category in staff_member.tags))

    MapSet.new(programs, & &1.id)
  end

  defp load_session_data(socket) do
    case Participation.get_session_with_roster_enriched(socket.assigns.session_id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:participation_records, session.participation_records || [])
        |> load_provider_notes()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, gettext("Session not found"))
        |> push_navigate(to: ~p"/staff/sessions")

      {:error, reason} ->
        Logger.error("[StaffParticipationLive] Failed to load session data",
          session_id: socket.assigns.session_id,
          reason: inspect(reason)
        )

        put_flash(socket, :error, gettext("Failed to load session data"))
    end
  end

  defp load_provider_notes(socket) do
    provider_id = socket.assigns.staff_member.provider_id
    records = socket.assigns.participation_records
    record_ids = Enum.map(records, & &1.id)

    notes = Participation.list_behavioral_notes_by_records_and_provider(record_ids, provider_id)
    notes_by_record = Map.new(notes, fn note -> {to_string(note.participation_record_id), note} end)
    notes_by_id = Map.new(notes, fn note -> {to_string(note.id), note} end)

    socket
    |> assign(:record_note_map, notes_by_record)
    |> assign(:provider_notes, notes_by_id)
  end

  defp find_participation_record(socket, record_id) do
    Enum.find(socket.assigns.participation_records, fn record ->
      to_string(record.id) == record_id
    end)
  end
end
```

- [ ] **Step 4: Create the HEEx template**

Create `lib/klass_hero_web/live/staff/staff_participation_live.html.heex`:

```heex
<div id="staff-participation" class="max-w-4xl mx-auto p-4 md:p-6">
  <%!-- Back button --%>
  <div class="mb-6">
    <.link
      navigate={~p"/staff/sessions"}
      class="inline-flex items-center gap-2 text-hero-blue-600 hover:text-hero-blue-700 font-medium"
    >
      <.icon name="hero-arrow-left" class="w-5 h-5" />
      <span>{gettext("Back to Sessions")}</span>
    </.link>
  </div>

  <%= if @session do %>
    <%!-- Session context card --%>
    <div class="mb-6">
      <.participation_card session={@session} role={:staff} />
    </div>

    <%!-- Roster list with individual actions --%>
    <div class="mt-6">
      <h2 class="text-xl font-semibold text-gray-900 mb-4">
        {gettext("Participation Management")}
      </h2>
      <.roster_list
        participation_records={@participation_records}
        session={@session}
        editable={true}
        checkout_form_expanded={@checkout_form_expanded}
        checkout_forms={@checkout_forms}
      >
        <:actions :let={record}>
          <%= cond do %>
            <%!-- Checked In: Show "Check Out" button (hide when form expanded) --%>
            <% record.status == :checked_in && @checkout_form_expanded != to_string(record.id) -> %>
              <button
                phx-click="expand_checkout_form"
                phx-value-id={record.id}
                class={[
                  "px-3 py-1.5 text-sm bg-blue-600 text-white font-medium hover:bg-blue-700",
                  "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
                  Theme.rounded(:md),
                  Theme.transition(:normal)
                ]}
              >
                {gettext("Check Out")}
              </button>
              <%!-- Checked Out: Show status text --%>
            <% record.status == :checked_out -> %>
              <span class="px-3 py-1.5 text-sm text-gray-500">
                {gettext("Checked Out")}
              </span>
              <%!-- Expected/Registered: Show Check In button --%>
            <% true -> %>
              <button
                phx-click="check_in"
                phx-value-id={record.id}
                class={[
                  "px-3 py-1.5 text-sm bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700",
                  "focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2",
                  Theme.rounded(:md),
                  Theme.transition(:normal)
                ]}
              >
                {gettext("Check In")}
              </button>
          <% end %>

          <%!-- Behavioral note section (only for checked-in / checked-out records) --%>
          <%= if record.status in [:checked_in, :checked_out] do %>
            <% existing_note = Map.get(@record_note_map, to_string(record.id)) %>
            <%= cond do %>
              <%!-- No note yet: show "Add Note" button --%>
              <% is_nil(existing_note) && @note_form_expanded != to_string(record.id) -> %>
                <button
                  id={"add-note-btn-#{record.id}"}
                  phx-click="expand_note_form"
                  phx-value-id={record.id}
                  class={[
                    "px-3 py-1.5 text-sm bg-amber-500 text-white font-medium hover:bg-amber-600",
                    "focus:outline-none focus:ring-2 focus:ring-amber-500 focus:ring-offset-2",
                    Theme.rounded(:md),
                    Theme.transition(:normal)
                  ]}
                >
                  {gettext("Add Note")}
                </button>
              <% is_nil(existing_note) && @note_form_expanded == to_string(record.id) -> %>
                <%!-- Note form expanded — handled in expanded_content slot --%>
              <% true -> %>
                <.note_status_badge
                  status={existing_note.status}
                  id={"note-badge-#{existing_note.id}"}
                />
            <% end %>
          <% end %>
        </:actions>

        <:expanded_content :let={record}>
          <%!-- Inline note form (full-width below record row) --%>
          <%= if @note_form_expanded == to_string(record.id) do %>
            <.behavioral_note_form
              form={Map.get(@note_forms, to_string(record.id))}
              record_id={to_string(record.id)}
            />
          <% end %>

          <%!-- Approved behavioral notes from past sessions (consent-gated) --%>
          <%= if Map.get(record, :behavioral_notes) do %>
            <.approved_notes_list
              notes={Map.get(record, :behavioral_notes, [])}
              record_id={to_string(record.id)}
            />
          <% end %>
        </:expanded_content>
      </.roster_list>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run tests**

Run: `mix test test/klass_hero_web/live/staff/staff_participation_live_test.exs`
Expected: All tests pass.

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: No regressions.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/staff/staff_participation_live.ex lib/klass_hero_web/live/staff/staff_participation_live.html.heex test/klass_hero_web/live/staff/staff_participation_live_test.exs
git commit -m "feat: implement StaffParticipationLive with check-in/check-out and behavioral notes"
```

---

## Task 7: Final Validation

**Files:** None (verification only)

- [ ] **Step 1: Run precommit checks**

Run: `mix precommit`
Expected: Compilation (warnings-as-errors), formatting, and all tests pass.

- [ ] **Step 2: Verify route existence**

Run: `mix phx.routes | grep staff`
Expected: Output shows all three staff routes:
```
/staff/dashboard     StaffDashboardLive     :index
/staff/sessions      StaffSessionsLive      :index
/staff/participation/:session_id  StaffParticipationLive  :show
```

- [ ] **Step 3: Verify no compiler warnings**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.
