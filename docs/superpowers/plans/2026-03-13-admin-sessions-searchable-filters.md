# Admin Sessions Searchable Filters — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace UUID-based filter inputs with searchable text dropdowns and merge today/filter modes into a unified view.

**Architecture:** Reusable `SearchableSelect` LiveComponent for dropdown state. Shared `KlassHero.Admin.Queries` module for cross-context read-only lookups. `SessionsLive` orchestrates filter state and cascading. Pure LiveView — no custom JS hooks.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL, Tailwind CSS, ExMachina (test factories)

**Spec:** `docs/superpowers/specs/2026-03-13-admin-sessions-searchable-filters-design.md`

**Skills:** @superpowers:test-driven-development, @idiomatic-elixir

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/klass_hero/admin/queries.ex` | Cross-context read-only queries for admin dropdowns |
| `lib/klass_hero_web/live/admin/components/searchable_select.ex` | Reusable LiveComponent: searchable dropdown with type-ahead filtering |
| `lib/klass_hero_web/live/admin/sessions_live.ex` | Orchestrates filter state, handles `:select` messages, preloads data |
| `lib/klass_hero_web/live/admin/sessions_live.html.heex` | Unified filter bar with SearchableSelect components |
| `test/klass_hero/admin/queries_test.exs` | Unit tests for Admin.Queries |
| `test/klass_hero_web/live/admin/components/searchable_select_test.exs` | LiveComponent tests |
| `test/klass_hero_web/live/admin/sessions_live_test.exs` | Updated integration tests |

---

## Chunk 1: Admin.Queries Module (TDD)

### Task 1: Admin.Queries — list_providers_for_select/0

**Files:**
- Create: `test/klass_hero/admin/queries_test.exs`
- Create: `lib/klass_hero/admin/queries.ex`

- [ ] **Step 1: Write the failing test**

Create `test/klass_hero/admin/queries_test.exs`:

```elixir
defmodule KlassHero.Admin.QueriesTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Admin.Queries

  describe "list_providers_for_select/0" do
    test "returns providers as %{id, label} maps sorted by name" do
      _provider_b = insert(:provider_profile_schema, business_name: "Zebra Sports")
      _provider_a = insert(:provider_profile_schema, business_name: "Alpha Arts")

      result = Queries.list_providers_for_select()

      assert [first | _] = result
      assert Map.keys(first) |> Enum.sort() == [:id, :label]
      assert first.label == "Alpha Arts"

      labels = Enum.map(result, & &1.label)
      assert "Alpha Arts" in labels
      assert "Zebra Sports" in labels

      # Verify sort order
      alpha_idx = Enum.find_index(result, &(&1.label == "Alpha Arts"))
      zebra_idx = Enum.find_index(result, &(&1.label == "Zebra Sports"))
      assert alpha_idx < zebra_idx
    end

    test "returns empty list when no providers exist" do
      assert Queries.list_providers_for_select() == []
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/admin/queries_test.exs --max-failures 1`
Expected: FAIL — `KlassHero.Admin.Queries` module not found

- [ ] **Step 3: Write minimal implementation**

Create `lib/klass_hero/admin/queries.ex`:

```elixir
defmodule KlassHero.Admin.Queries do
  @moduledoc """
  Cross-context read-only queries for admin dashboard dropdowns.

  Returns plain maps for select/dropdown options. No domain logic.
  Located in the data layer because it executes Ecto/Repo queries directly.
  """

  import Ecto.Query

  alias KlassHero.Repo

  @doc """
  Returns all providers as `%{id: uuid, label: business_name}` maps,
  sorted alphabetically by business name.
  """
  def list_providers_for_select do
    from(p in "providers",
      select: %{id: type(p.id, :binary_id), label: p.business_name},
      order_by: [asc: p.business_name]
    )
    |> Repo.all()
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/admin/queries_test.exs`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/admin/queries_test.exs lib/klass_hero/admin/queries.ex
git commit -m "feat: add Admin.Queries.list_providers_for_select/0

Cross-context read-only query returning provider options for admin
dropdown selects. Returns %{id, label} maps sorted by business name."
```

### Task 2: Admin.Queries — list_programs_for_select/0

**Files:**
- Modify: `test/klass_hero/admin/queries_test.exs`
- Modify: `lib/klass_hero/admin/queries.ex`

- [ ] **Step 1: Write the failing test**

Add to `test/klass_hero/admin/queries_test.exs`:

```elixir
describe "list_programs_for_select/0" do
  test "returns programs as %{id, label, provider_id} maps sorted by title" do
    provider = insert(:provider_profile_schema)
    insert(:program_schema, provider_id: provider.id, title: "Yoga Flow")
    insert(:program_schema, provider_id: provider.id, title: "Art Adventures")

    result = Queries.list_programs_for_select()

    assert [first | _] = result
    assert Map.keys(first) |> Enum.sort() == [:id, :label, :provider_id]
    assert first.label == "Art Adventures"
    assert first.provider_id == provider.id
  end

  test "returns empty list when no programs exist" do
    assert Queries.list_programs_for_select() == []
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/admin/queries_test.exs --max-failures 1`
Expected: FAIL — `list_programs_for_select/0` undefined

- [ ] **Step 3: Write minimal implementation**

Add to `lib/klass_hero/admin/queries.ex`:

```elixir
@doc """
Returns all programs as `%{id: uuid, label: title, provider_id: uuid}` maps,
sorted alphabetically by title.

Includes `provider_id` so the parent LiveView can filter programs in-memory
when a provider is selected (cascading dropdown).
"""
def list_programs_for_select do
  from(p in "programs",
    select: %{
      id: type(p.id, :binary_id),
      label: p.title,
      provider_id: type(p.provider_id, :binary_id)
    },
    order_by: [asc: p.title]
  )
  |> Repo.all()
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/admin/queries_test.exs`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/admin/queries_test.exs lib/klass_hero/admin/queries.ex
git commit -m "feat: add Admin.Queries.list_programs_for_select/0

Returns program options with provider_id for cascading dropdown filtering."
```

---

## Chunk 2: SearchableSelect LiveComponent (TDD)

### Task 3: SearchableSelect — renders with label and placeholder

**Files:**
- Create: `test/klass_hero_web/live/admin/components/searchable_select_test.exs`
- Create: `lib/klass_hero_web/live/admin/components/searchable_select.ex`

- [ ] **Step 1: Write the failing test**

Create `test/klass_hero_web/live/admin/components/searchable_select_test.exs`:

```elixir
defmodule KlassHeroWeb.Admin.Components.SearchableSelectTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.Admin.Components.SearchableSelect

  @options [
    %{id: "id-1", label: "Alpha Arts"},
    %{id: "id-2", label: "Beta Sports"},
    %{id: "id-3", label: "Creative Learning"}
  ]

  # Test harness LiveView to host the LiveComponent for isolated testing.
  # LiveComponents cannot be tested with live_isolated — they need a parent LiveView.
  defmodule HarnessLive do
    use Phoenix.LiveView

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> assign(:options, session["options"] || [])
       |> assign(:selected, session["selected"])
       |> assign(:label, session["label"] || "Test")
       |> assign(:placeholder, session["placeholder"] || "Search...")
       |> assign(:field_name, session["field_name"] || "test_field")
       |> assign(:select_events, [])}
    end

    @impl true
    def handle_info({:select, field_name, selected}, socket) do
      {:noreply,
       socket
       |> assign(:selected, selected)
       |> update(:select_events, &[{field_name, selected} | &1])}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div id="harness">
        <.live_component
          module={SearchableSelect}
          id="test-select"
          label={@label}
          placeholder={@placeholder}
          field_name={@field_name}
          options={@options}
          selected={@selected}
        />
        <span id="event-count">{length(@select_events)}</span>
      </div>
      """
    end
  end

  defp mount_harness(conn, opts \\ %{}) do
    session =
      Map.merge(
        %{
          "options" => @options,
          "selected" => nil,
          "label" => "Provider",
          "placeholder" => "All providers",
          "field_name" => "provider_id"
        },
        opts
      )

    live_isolated(conn, HarnessLive, session: session)
  end

  describe "rendering" do
    test "renders label and placeholder", %{conn: conn} do
      {:ok, view, html} = mount_harness(conn)

      assert html =~ "Provider"
      assert has_element?(view, "[placeholder=\"All providers\"]")
    end

    test "renders hidden input with field_name", %{conn: conn} do
      {:ok, view, _html} = mount_harness(conn)

      assert has_element?(view, "input[type=hidden][name=provider_id]")
    end
  end
end
```

**Note:** The test uses a `HarnessLive` LiveView to host the LiveComponent since `live_isolated` only works with LiveViews, not LiveComponents. The harness captures `:select` messages for assertion.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/admin/components/searchable_select_test.exs --max-failures 1`
Expected: FAIL — module `SearchableSelect` not found

- [ ] **Step 3: Write minimal implementation**

Create `lib/klass_hero_web/live/admin/components/searchable_select.ex`:

```elixir
defmodule KlassHeroWeb.Admin.Components.SearchableSelect do
  @moduledoc """
  Reusable searchable dropdown LiveComponent for admin views.

  Encapsulates dropdown state (search term, open/closed, filtered options).
  LiveComponent is necessary here because each instance needs independent
  mutable state — a function component cannot hold per-instance state.

  ## Usage from a parent LiveView

      <.live_component
        module={SearchableSelect}
        id="provider-select"
        label="Provider"
        placeholder="All providers"
        field_name="provider_id"
        options={@providers}
        selected={@selected_provider}
      />

  When the user selects an option, sends to parent:
  `{:select, "provider_id", %{id: "uuid", label: "Name"}}`

  When the user clears the selection, sends:
  `{:select, "provider_id", nil}`
  """

  use KlassHeroWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_term, "")
     |> assign(:open?, false)
     |> assign(:filtered_options, [])}
  end

  @impl true
  def update(%{id: id} = assigns, socket) do
    # Trigger: props arrive from parent on mount and on every parent re-render
    # Why: must update options (e.g. program list narrowed by provider) while
    #      preserving any in-progress search the user is typing
    # Outcome: re-filter options against current search_term if options changed
    options = assigns[:options] || []
    selected = assigns[:selected]
    current_term = socket.assigns[:search_term] || ""

    filtered =
      if current_term == "" do
        options
      else
        downcased = String.downcase(current_term)
        Enum.filter(options, fn opt -> String.downcase(opt.label) |> String.contains?(downcased) end)
      end

    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:label, assigns[:label] || "")
     |> assign(:placeholder, assigns[:placeholder] || "Search...")
     |> assign(:field_name, assigns[:field_name] || "")
     |> assign(:options, options)
     |> assign(:selected, selected)
     |> assign(:filtered_options, filtered)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="relative" phx-click-away="close" phx-target={@myself}>
      <label :if={@label != ""} class="label label-text text-xs font-medium uppercase tracking-wide">
        {@label}
      </label>

      <div :if={@selected} class="flex items-center gap-2">
        <span class="input input-bordered input-sm flex-1 flex items-center">
          {@selected.label}
        </span>
        <button
          type="button"
          phx-click="clear"
          phx-target={@myself}
          class="btn btn-ghost btn-xs"
          aria-label={gettext("Clear selection")}
        >
          ×
        </button>
        <input type="hidden" name={@field_name} value={@selected.id} />
      </div>

      <%!-- Wrap in <form> because phx-change requires a form ancestor --%>
      <form :if={!@selected} phx-change="search" phx-submit="noop" phx-target={@myself}>
        <input
          type="text"
          placeholder={@placeholder}
          value={@search_term}
          phx-focus="open"
          phx-debounce="300"
          phx-target={@myself}
          name={"#{@field_name}_search"}
          class="input input-bordered input-sm w-full"
          autocomplete="off"
        />
        <input type="hidden" name={@field_name} value="" />

        <ul
          :if={@open?}
          class="absolute z-50 mt-1 w-full bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-48 overflow-y-auto"
        >
          <li :if={@filtered_options == []} class="px-3 py-2 text-sm opacity-50">
            {gettext("No results")}
          </li>
          <li
            :for={option <- @filtered_options}
            phx-click="select"
            phx-value-id={option.id}
            phx-value-label={option.label}
            phx-target={@myself}
            class="px-3 py-2 text-sm cursor-pointer hover:bg-base-200"
          >
            {option.label}
          </li>
        </ul>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("search", params, socket) do
    # Trigger: phx-change on the component's internal form sends all input values
    # Why: form sends %{"provider_id_search" => "text", "provider_id" => ""} etc.
    # Outcome: extract search term from the params map by the input's name key
    search_key = "#{socket.assigns.field_name}_search"
    term = params[search_key] || ""

    filtered =
      if term == "" do
        socket.assigns.options
      else
        downcased = String.downcase(term)

        Enum.filter(socket.assigns.options, fn opt ->
          String.downcase(opt.label) |> String.contains?(downcased)
        end)
      end

    {:noreply,
     socket
     |> assign(:search_term, term)
     |> assign(:open?, true)
     |> assign(:filtered_options, filtered)}
  end

  @impl true
  def handle_event("open", _params, socket) do
    {:noreply,
     socket
     |> assign(:open?, true)
     |> assign(:filtered_options, socket.assigns.options)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :open?, false)}
  end

  @impl true
  def handle_event("select", %{"id" => id, "label" => label}, socket) do
    selected = %{id: id, label: label}
    send(self(), {:select, socket.assigns.field_name, selected})

    {:noreply,
     socket
     |> assign(:selected, selected)
     |> assign(:search_term, "")
     |> assign(:open?, false)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    send(self(), {:select, socket.assigns.field_name, nil})

    {:noreply,
     socket
     |> assign(:selected, nil)
     |> assign(:search_term, "")
     |> assign(:open?, false)}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/admin/components/searchable_select_test.exs`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/admin/components/searchable_select.ex test/klass_hero_web/live/admin/components/searchable_select_test.exs
git commit -m "feat: add SearchableSelect LiveComponent with basic rendering

Reusable searchable dropdown for admin views. Renders label,
placeholder, hidden input, and option list with type-ahead filtering."
```

### Task 4: SearchableSelect — filtering and selection behavior

**Files:**
- Modify: `test/klass_hero_web/live/admin/components/searchable_select_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to the test file:

```elixir
describe "filtering" do
  test "filters options by search term (case-insensitive)", %{conn: conn} do
    {:ok, view, _html} = mount_harness(conn)

    # Type "alpha" — should filter to just Alpha Arts
    view
    |> element("input[name=provider_id_search]")
    |> render_change(%{"provider_id_search" => "alpha"})

    html = render(view)
    assert html =~ "Alpha Arts"
    refute html =~ "Beta Sports"
    refute html =~ "Creative Learning"
  end

  test "shows 'No results' when nothing matches", %{conn: conn} do
    {:ok, view, _html} = mount_harness(conn)

    view
    |> element("input[name=provider_id_search]")
    |> render_change(%{"provider_id_search" => "nonexistent"})

    assert render(view) =~ "No results"
  end
end

describe "selection" do
  test "displays selected value and clear button", %{conn: conn} do
    selected = %{id: "id-1", label: "Alpha Arts"}

    {:ok, view, _html} = mount_harness(conn, %{"selected" => selected})

    html = render(view)
    assert html =~ "Alpha Arts"
    assert has_element?(view, "input[type=hidden][name=provider_id][value=id-1]")
    assert has_element?(view, "button[phx-click=clear]")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail or pass**

Run: `mix test test/klass_hero_web/live/admin/components/searchable_select_test.exs`
Expected: All tests pass (implementation already covers these behaviors). If any fail, fix the implementation.

- [ ] **Step 3: Commit**

```bash
git add test/klass_hero_web/live/admin/components/searchable_select_test.exs
git commit -m "test: add filtering and selection tests for SearchableSelect"
```

---

## Chunk 3: SessionsLive Refactor (TDD)

### Task 5: Update SessionsLive — remove mode logic, add filter state

**Files:**
- Modify: `lib/klass_hero_web/live/admin/sessions_live.ex`
- Modify: `test/klass_hero_web/live/admin/sessions_live_test.exs`

- [ ] **Step 1: Write the failing tests for unified filter bar**

Replace the `"today mode"` and `"filter mode"` describe blocks in `test/klass_hero_web/live/admin/sessions_live_test.exs` with:

```elixir
describe "unified filter bar" do
  setup :register_and_log_in_admin

  setup do
    provider = insert(:provider_profile_schema, business_name: "Creative Learning Inc.")
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

  test "displays sessions with program and provider names", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    assert has_element?(view, "#sessions-list")
    assert render(view) =~ "Art Adventures"
    assert render(view) =~ "Creative Learning Inc."
  end

  test "shows attendance count", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/sessions")
    assert html =~ "1 / 1"
  end

  test "renders provider searchable select", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    assert has_element?(view, "#provider-select")
  end

  test "renders program searchable select", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    assert has_element?(view, "#program-select")
  end

  test "renders date inputs defaulting to today", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    today = Date.utc_today() |> Date.to_iso8601()
    assert has_element?(view, "input[name=date_from][value='#{today}']")
    assert has_element?(view, "input[name=date_to][value='#{today}']")
  end

  test "renders status dropdown", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    assert has_element?(view, "select[name=status]")
  end

  test "no mode switcher exists", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    refute has_element?(view, "#mode-today")
    refute has_element?(view, "#mode-filter")
  end

  test "always shows session date in rows", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/sessions")
    today = Date.utc_today() |> Date.to_iso8601()
    assert html =~ today
  end

  test "filtering by status re-queries sessions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")

    view
    |> element("#filter-bar")
    |> render_change(%{"status" => "completed"})

    # Session is in_progress, so filtering for completed should hide it
    refute render(view) =~ "Art Adventures"
  end

  test "filtering by date range excludes sessions outside range", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/sessions")
    yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()

    view
    |> element("#filter-bar")
    |> render_change(%{"date_from" => yesterday, "date_to" => yesterday})

    # Session is today, so filtering for yesterday should hide it
    refute render(view) =~ "Art Adventures"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/sessions_live_test.exs --max-failures 1`
Expected: FAIL — mode switcher elements still exist, searchable selects don't exist yet

- [ ] **Step 3: Update SessionsLive implementation**

Modify `lib/klass_hero_web/live/admin/sessions_live.ex`:

```elixir
defmodule KlassHeroWeb.Admin.SessionsLive do
  @moduledoc """
  Admin dashboard for participation sessions.

  Unified view with searchable provider/program dropdowns,
  date range, and status filter. All filters apply live.
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Admin.Queries
  alias KlassHero.Participation
  alias KlassHeroWeb.Admin.Components.SearchableSelect
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    all_providers = Queries.list_providers_for_select()
    all_programs = Queries.list_programs_for_select()

    {:ok,
     socket
     |> assign(:fluid?, false)
     |> assign(:live_resource, nil)
     |> assign(:page_title, gettext("Sessions"))
     |> assign(:session_statuses, Participation.session_statuses())
     |> assign(:all_providers, all_providers)
     |> assign(:all_programs, all_programs)
     |> assign(:filtered_programs, all_programs)
     |> assign(:selected_provider, nil)
     |> assign(:selected_program, nil)
     |> assign(:date_from, today)
     |> assign(:date_to, today)
     |> assign(:selected_status, nil)}
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
    load_sessions(socket)
  end

  # Trigger: id param arrives from URL as raw string
  # Why: non-UUID strings cause Ecto.Query.CastError before Repo.get executes
  # Outcome: invalid UUIDs redirect to index with error flash instead of crashing
  defp apply_action(socket, :show, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Participation.get_session_with_roster_enriched(uuid) do
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

      :error ->
        socket
        |> put_flash(:error, gettext("Session not found"))
        |> push_navigate(to: ~p"/admin/sessions")
    end
  end

  # -- Filter Event Handlers --

  @impl true
  def handle_info({:select, "provider_id", selected}, socket) do
    # Trigger: user selected or cleared a provider in the SearchableSelect
    # Why: selecting a provider must cascade to narrow program options
    # Outcome: filter programs in-memory, clear program if it doesn't belong
    filtered_programs =
      case selected do
        nil ->
          socket.assigns.all_programs

        %{id: provider_id} ->
          Enum.filter(socket.assigns.all_programs, &(&1.provider_id == provider_id))
      end

    # Trigger: selected program may not belong to the newly selected provider
    # Why: showing a stale program selection would produce confusing results
    # Outcome: clear program selection if it's not in the filtered list
    selected_program =
      case socket.assigns.selected_program do
        nil ->
          nil

        %{id: program_id} ->
          if Enum.any?(filtered_programs, &(&1.id == program_id)) do
            socket.assigns.selected_program
          else
            nil
          end
      end

    socket
    |> assign(:selected_provider, selected)
    |> assign(:filtered_programs, filtered_programs)
    |> assign(:selected_program, selected_program)
    |> load_sessions()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:select, "program_id", selected}, socket) do
    socket
    |> assign(:selected_program, selected)
    |> load_sessions()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    # Trigger: unified filter bar form emits phx-change on any input change
    # Why: single handler for date and status changes avoids per-input phx-change attrs
    # Outcome: parse all filter params, update assigns, reload sessions
    date_from = parse_date(params["date_from"], socket.assigns.date_from)
    date_to = parse_date(params["date_to"], socket.assigns.date_to)
    selected_status = parse_status(params["status"])

    socket
    |> assign(:date_from, date_from)
    |> assign(:date_to, date_to)
    |> assign(:selected_status, selected_status)
    |> load_sessions()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("reset_dates", _params, socket) do
    today = Date.utc_today()

    socket
    |> assign(:date_from, today)
    |> assign(:date_to, today)
    |> load_sessions()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("open_correction", %{"record-id" => record_id}, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, record_id)
     |> assign(:correction_form, to_form(%{"reason" => ""}, as: :correction))}
  end

  @impl true
  def handle_event("cancel_correction", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, nil)
     |> assign(:correction_form, nil)}
  end

  @impl true
  def handle_event("save_correction", %{"correction" => correction_params}, socket) do
    record_id = socket.assigns.editing_record_id

    base_params =
      %{record_id: record_id, reason: correction_params["reason"]}
      |> maybe_put_status(correction_params)

    with {:ok, params} <-
           maybe_put_time(base_params, :check_in_at, correction_params["check_in_at"]),
         {:ok, params} <- maybe_put_time(params, :check_out_at, correction_params["check_out_at"]),
         {:ok, _corrected} <- Participation.correct_attendance(params),
         {:ok, session} <-
           Participation.get_session_with_roster_enriched(socket.assigns.session.id) do
      {:noreply,
       socket
       |> assign(:session, session)
       |> assign(:editing_record_id, nil)
       |> assign(:correction_form, nil)
       |> put_flash(:info, gettext("Attendance corrected successfully"))}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  # -- Private Helpers --

  defp load_sessions(socket) do
    filters = build_filters(socket.assigns)
    sessions = Participation.list_admin_sessions(filters)
    stream(socket, :sessions, sessions, reset: true)
  end

  defp build_filters(assigns) do
    %{}
    |> maybe_add_filter(:provider_id, get_in(assigns, [:selected_provider, :id]))
    |> maybe_add_filter(:program_id, get_in(assigns, [:selected_program, :id]))
    |> maybe_add_filter(:status, assigns.selected_status)
    |> maybe_add_date_range(assigns.date_from, assigns.date_to)
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_date_range(filters, %Date{} = from, %Date{} = to) when from == to,
    do: Map.put(filters, :date, from)

  defp maybe_add_date_range(filters, %Date{} = from, %Date{} = to),
    do: Map.merge(filters, %{date_from: from, date_to: to})

  defp maybe_add_date_range(filters, _, _), do: filters

  defp parse_date("", fallback), do: fallback
  defp parse_date(nil, fallback), do: fallback

  defp parse_date(date_string, fallback) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> fallback
    end
  end

  @session_status_strings ~w(scheduled in_progress completed cancelled)
  @record_status_strings ~w(registered checked_in checked_out absent)

  defp parse_status(""), do: nil
  defp parse_status(nil), do: nil
  defp parse_status(s) when s in @session_status_strings, do: String.to_existing_atom(s)
  defp parse_status(_), do: nil

  defp maybe_put_status(params, %{"status" => ""}), do: params

  defp maybe_put_status(params, %{"status" => s}) when s in @record_status_strings,
    do: Map.put(params, :status, String.to_existing_atom(s))

  defp maybe_put_status(params, _), do: params

  defp maybe_put_time(params, _key, nil), do: {:ok, params}
  defp maybe_put_time(params, _key, ""), do: {:ok, params}

  defp maybe_put_time(params, key, time_string) do
    # Trigger: datetime-local inputs submit "YYYY-MM-DDTHH:MM" (no timezone, no seconds)
    # Why: NaiveDateTime.from_iso8601 requires seconds; datetime-local omits them
    # Outcome: normalize by appending ":00", parse as NaiveDateTime, convert to UTC
    normalized = normalize_datetime_local(time_string)

    case NaiveDateTime.from_iso8601(normalized) do
      {:ok, ndt} -> {:ok, Map.put(params, key, DateTime.from_naive!(ndt, "Etc/UTC"))}
      _ -> {:error, :invalid_time}
    end
  end

  # Trigger: HTML datetime-local inputs submit "YYYY-MM-DDTHH:MM" (16 chars, no seconds)
  # Why: NaiveDateTime.from_iso8601/1 requires "YYYY-MM-DDTHH:MM:SS" format
  # Outcome: appends ":00" to match the expected format
  defp normalize_datetime_local(s) when byte_size(s) == 16, do: s <> ":00"
  defp normalize_datetime_local(s), do: s

  defp error_message(:reason_required), do: gettext("A reason is required for corrections")
  defp error_message(:no_changes), do: gettext("No changes detected")
  defp error_message(:not_found), do: gettext("Record not found")

  defp error_message(:stale_data),
    do: gettext("Record was modified by someone else. Please refresh.")

  defp error_message(:check_out_requires_check_in),
    do: gettext("Cannot check out without a check-in")

  defp error_message(:check_in_must_precede_check_out),
    do: gettext("Check-in time must be before check-out time")

  defp error_message(:invalid_time), do: gettext("Invalid time format")

  defp error_message(_), do: gettext("An error occurred")

  # -- View Helpers (used in template) --

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

    cond do
      notes == [] ->
        "—"

      Enum.any?(notes, &(&1.status == :approved)) ->
        gettext("Approved")

      Enum.any?(notes, &(&1.status == :pending_approval)) ->
        gettext("Pending")

      true ->
        "—"
    end
  end
end
```

- [ ] **Step 4: Update the template**

Replace `lib/klass_hero_web/live/admin/sessions_live.html.heex`:

```heex
<%!-- Index view --%>
<div :if={@live_action == :index}>
  <div class="mb-6">
    <h1 class={Theme.typography(:page_title)}>{gettext("Sessions")}</h1>
  </div>

  <%!-- Unified filter bar --%>
  <%!-- SearchableSelects have their own internal forms, so they live outside #filter-bar --%>
  <div class="flex flex-wrap gap-3 mb-4 items-end">
    <div class="w-full sm:w-auto sm:min-w-[200px]">
      <.live_component
        module={SearchableSelect}
        id="provider-select"
        label={gettext("Provider")}
        placeholder={gettext("All providers")}
        field_name="provider_id"
        options={@all_providers}
        selected={@selected_provider}
      />
    </div>

    <div class="w-full sm:w-auto sm:min-w-[200px]">
      <.live_component
        module={SearchableSelect}
        id="program-select"
        label={gettext("Program")}
        placeholder={gettext("All programs")}
        field_name="program_id"
        options={@filtered_programs}
        selected={@selected_program}
      />
    </div>

    <%!-- Date/status filters in their own form for phx-change --%>
    <form id="filter-bar" phx-change="filter_change" class="contents">
      <div class="flex gap-2 items-end">
        <div>
          <label class="label label-text text-xs font-medium uppercase tracking-wide">
            {gettext("From")}
          </label>
          <input
            type="date"
            name="date_from"
            value={Date.to_iso8601(@date_from)}
            phx-debounce="300"
            class="input input-bordered input-sm"
          />
        </div>
        <div>
          <label class="label label-text text-xs font-medium uppercase tracking-wide">
            {gettext("To")}
          </label>
          <input
            type="date"
            name="date_to"
            value={Date.to_iso8601(@date_to)}
            phx-debounce="300"
            class="input input-bordered input-sm"
          />
        </div>
        <button
          type="button"
          phx-click="reset_dates"
          class="btn btn-ghost btn-xs mb-1"
          title={gettext("Reset to today")}
        >
          ↻
        </button>
      </div>

      <div>
        <label class="label label-text text-xs font-medium uppercase tracking-wide">
          {gettext("Status")}
        </label>
        <select
          name="status"
          class="select select-bordered select-sm"
        >
          <option value="">{gettext("All Statuses")}</option>
          <option :for={status <- @session_statuses} value={status}>
            {humanize_status(status)}
          </option>
        </select>
      </div>
    </form>
  </div>

  <%!-- Session list --%>
  <div id="sessions-list" phx-update="stream" class="space-y-1">
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
            {session.provider_name} · {session.session_date} ·
            {Calendar.strftime(session.start_time, "%H:%M")}–{Calendar.strftime(
              session.end_time,
              "%H:%M"
            )}
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

<%!-- Show view (unchanged) --%>
<div :if={@live_action == :show}>
  <div class="mb-6">
    <.link
      navigate={~p"/admin/sessions"}
      class="text-sm opacity-50 hover:opacity-100 mb-2 inline-block"
    >
      ← {gettext("Back to sessions")}
    </.link>
    <div class="flex justify-between items-start flex-wrap gap-2">
      <div>
        <h1 class={Theme.typography(:section_title)}>
          {@session.program_name || @session.program_id}
        </h1>
        <div class="text-sm opacity-50 mt-1">
          {@session.session_date} · {Calendar.strftime(@session.start_time, "%H:%M")}–{Calendar.strftime(
            @session.end_time,
            "%H:%M"
          )}
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
                <.form
                  for={@correction_form}
                  id="correction-form"
                  phx-submit="save_correction"
                  class="p-4 space-y-3"
                >
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
                      <input
                        type="datetime-local"
                        name="correction[check_in_at]"
                        class="input input-bordered input-sm"
                        value={format_datetime_local(record.check_in_at)}
                      />
                    </div>
                    <div class="form-control">
                      <label class="label label-text text-xs">{gettext("Check-out time")}</label>
                      <input
                        type="datetime-local"
                        name="correction[check_out_at]"
                        class="input input-bordered input-sm"
                        value={format_datetime_local(record.check_out_at)}
                      />
                    </div>
                  </div>
                  <div class="form-control">
                    <label class="label label-text text-xs">
                      {gettext("Reason for correction")} *
                    </label>
                    <textarea
                      name="correction[reason]"
                      class="textarea textarea-bordered textarea-sm"
                      required
                      placeholder={gettext("Explain why this correction is needed...")}
                    ></textarea>
                  </div>
                  <div class="flex gap-2 justify-end">
                    <button
                      type="button"
                      id="cancel-correction"
                      phx-click="cancel_correction"
                      class="btn btn-ghost btn-sm"
                    >
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

- [ ] **Step 5: Run all tests**

Run: `mix test test/klass_hero_web/live/admin/sessions_live_test.exs`
Expected: All tests pass

- [ ] **Step 6: Run full precommit**

Run: `mix precommit`
Expected: All checks pass (compile with warnings-as-errors, format, test)

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/admin/sessions_live.ex lib/klass_hero_web/live/admin/sessions_live.html.heex test/klass_hero_web/live/admin/sessions_live_test.exs
git commit -m "feat: replace UUID filters with searchable dropdowns in admin sessions

Remove today/filter mode toggle. Add unified filter bar with:
- SearchableSelect for provider (cascades to program)
- SearchableSelect for program
- Date range inputs (default to today)
- Status dropdown

All filters apply live on change."
```

### Task 6: Final verification — full test suite

- [ ] **Step 1: Run full test suite**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 2: Verify no warnings**

The precommit pipeline includes `--warnings-as-errors`. If any unused variable, missing alias, or other warning exists, fix it before proceeding.

- [ ] **Step 3: Manual smoke test (if Phoenix server running)**

If Playwright or Tidewave MCP is available:
1. Navigate to `http://localhost:4000/admin/sessions`
2. Verify searchable dropdowns render
3. Type in provider field — verify filtering
4. Select a provider — verify program dropdown narrows
5. Clear provider — verify all programs return
6. Click a session — verify detail/correction flow still works
