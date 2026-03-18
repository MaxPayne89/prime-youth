# Provider Create Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use the `superpowers:test-driven-development` and `idiomatic-elixir` skills throughout.

**Goal:** Add "Create Session" form to the provider Sessions LiveView, plus fix three pre-existing PubSub bugs.

**Architecture:** Modal form on `/provider/sessions/new` calls existing `Participation.create_session/1`. PubSub bug fixes (topic alignment, message format, stream data shape) are prerequisite. Programs loaded from `ProgramCatalog.list_programs_for_provider/1` (CQRS read model).

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Tailwind CSS

**Spec:** `docs/superpowers/specs/2026-03-18-provider-create-session-design.md`

---

## File Map

| File | Action | Responsibility |
| ---- | ------ | -------------- |
| `lib/klass_hero_web/router.ex` | Modify (line 87) | Add `:new` live action route |
| `lib/klass_hero_web/live/provider/sessions_live.ex` | Modify | PubSub fixes, handle_params, form handlers, program loading |
| `lib/klass_hero_web/live/provider/sessions_live.html.heex` | Modify | Create button, modal markup, form template |
| `test/klass_hero_web/live/provider/sessions_live_test.exs` | Modify | All new tests |

No new files created. No migrations.

## Important Context for Implementation

### Test Data Setup

Tests need **both** a `program_schema` (for FK constraints on sessions) and a `program_listing_schema` (for `ProgramCatalog.list_programs_for_provider/1` which reads from the CQRS read model table). Use the **same ID** for both:

```elixir
program_id = Ecto.UUID.generate()
program = insert(:program_schema, id: program_id, provider_id: provider.id)
_listing = insert(:program_listing_schema, id: program_id, provider_id: provider.id)
```

### PubSub Message Format

Events are broadcast as `{:domain_event, %DomainEvent{}}` tuples. All `handle_info` clauses must match this tuple format. The current SessionsLive incorrectly matches bare `%DomainEvent{}`.

### Stream Data Shape

`load_sessions` streams `ProgramSession.t()` structs. `get_session_with_roster/1` returns `{:ok, %{session: ProgramSession.t(), roster: [...]}}`. The existing `update_session_in_stream` destructures incorrectly — must use `{:ok, %{session: session}}`.

### Type Coercion

HTML form params arrive as string-keyed maps with string values. `CreateSession.execute/1` expects atom keys with typed values (`Date.t()`, `Time.t()`). HTML `<input type="time">` produces `"HH:MM"` — must append `":00"` for `Time.from_iso8601!/1`.

---

## Task 1: Fix PubSub Bugs and Load Provider Programs

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Background

Three pre-existing bugs prevent PubSub real-time updates from working:
1. Topic mismatch — subscribes to `"participation:provider:#{id}"`, events publish to `"participation:session_started"` etc.
2. Message format — matches bare `%DomainEvent{}`, should be `{:domain_event, %DomainEvent{}}`
3. Stream data shape — `update_session_in_stream` inserts `%{session: ..., roster: ...}` map into a stream of `ProgramSession.t()` structs

Program loading is included in this task because the PubSub `handle_info` filters events by `provider_program_ids` — the test needs a populated MapSet to pass.

### Steps

- [ ] **Step 1: Write test for PubSub session_started update**

Add to `test/klass_hero_web/live/provider/sessions_live_test.exs`:

```elixir
describe "PubSub real-time updates" do
  setup :register_and_log_in_provider

  test "updates session in stream when session_started event received", %{
    conn: conn,
    provider: provider
  } do
    program = insert(:program_schema, provider_id: provider.id)
    # Need listing so mount can build provider_program_ids MapSet
    _listing = insert(:program_listing_schema, id: program.id, provider_id: provider.id)

    session =
      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

    {:ok, view, _html} = live(conn, ~p"/provider/sessions")

    # Session initially shows Start button
    assert has_element?(view, "button", "Start Session")

    # Simulate PubSub event (matching actual broadcast format)
    event =
      KlassHero.Participation.Domain.Events.ParticipationEvents.session_started(
        struct!(KlassHero.Participation.Domain.Models.ProgramSession, %{
          id: session.id,
          program_id: program.id,
          session_date: Date.utc_today(),
          start_time: ~T[15:00:00],
          end_time: ~T[17:00:00],
          status: :in_progress
        })
      )

    # Transition the session in DB so the re-fetch picks it up
    {:ok, _} = Participation.start_session(session.id)

    send(view.pid, {:domain_event, event})

    # After PubSub update, should show in_progress actions
    assert has_element?(view, "a", "Manage Participation")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs --only describe:"PubSub real-time updates"`

Expected: FAIL — `handle_info` doesn't match `{:domain_event, ...}` tuple and subscribes to wrong topic.

- [ ] **Step 3: Fix PubSub subscriptions in mount**

In `sessions_live.ex`, replace the subscription block (lines 21-26):

```elixir
# Before (broken):
if connected?(socket) do
  Phoenix.PubSub.subscribe(
    KlassHero.PubSub,
    "participation:provider:#{provider_id}"
  )
end

# After (fixed):
if connected?(socket) do
  # Trigger: subscribing to generic event topics (not provider-specific)
  # Why: event system publishes to "aggregate:event_type" topics;
  #      provider-specific routing is a future enhancement (see follow-up issue)
  # Outcome: handle_info receives all events, filters by provider's program IDs
  for topic <- [
        "participation:session_created",
        "participation:session_started",
        "participation:session_completed",
        "participation:child_checked_in"
      ] do
    Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
  end
end
```

- [ ] **Step 4: Fix handle_info message format and add program_id filtering**

Replace the existing `handle_info` clauses (lines 94-114):

```elixir
# PubSub event handlers — session lifecycle events
@impl true
def handle_info(
      {:domain_event,
       %KlassHero.Shared.Domain.Events.DomainEvent{
         event_type: event_type,
         aggregate_id: session_id,
         payload: %{program_id: program_id}
       }},
      socket
    )
    when event_type in [:session_started, :session_completed, :session_created] do
  # Trigger: generic topic delivers events for ALL providers' sessions
  # Why: we only subscribe to generic topics (not provider-specific)
  # Outcome: ignore events for programs not belonging to this provider
  if MapSet.member?(socket.assigns.provider_program_ids, program_id) do
    {:noreply, update_session_in_stream(socket, session_id)}
  else
    {:noreply, socket}
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
  # Trigger: child_checked_in payload lacks program_id
  # Why: event only carries session_id and child_id
  # Outcome: attempt fetch — if session not in stream, stream_insert is harmless
  {:noreply, update_session_in_stream(socket, session_id)}
end
```

Also add program loading to mount (needed for the MapSet filter):

```elixir
alias KlassHero.ProgramCatalog

# In mount, after provider_id assignment:
provider_programs = ProgramCatalog.list_programs_for_provider(provider_id)
provider_program_ids = MapSet.new(provider_programs, & &1.id)

# Add to the socket pipeline:
|> assign(:provider_programs, provider_programs)
|> assign(:provider_program_ids, provider_program_ids)
```

- [ ] **Step 5: Fix update_session_in_stream data shape**

Replace the existing function (lines 130-144):

```elixir
defp update_session_in_stream(socket, session_id) do
  case Participation.get_session_with_roster(session_id) do
    {:ok, %{session: session}} ->
      stream_insert(socket, :sessions, session)

    {:error, reason} ->
      Logger.error(
        "[SessionsLive.update_session_in_stream] Failed to fetch session",
        session_id: session_id,
        reason: inspect(reason)
      )

      socket
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS (including existing tests)

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.ex test/klass_hero_web/live/provider/sessions_live_test.exs
git commit -m "fix: correct PubSub subscriptions, message format, and stream shape in SessionsLive"
```

---

## Task 2: Add Route and handle_params

**Files:**
- Modify: `lib/klass_hero_web/router.ex` (line 87)
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Steps

- [ ] **Step 1: Write test for navigating to create session route**

```elixir
describe "create session modal" do
  setup :register_and_log_in_provider

  test "navigating to /provider/sessions/new shows modal", %{conn: conn, provider: provider} do
    _listing = insert(:program_listing_schema, provider_id: provider.id)

    {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

    assert has_element?(view, "#create-session-modal")
    assert has_element?(view, "#create-session-form")
  end

  test "navigating back to /provider/sessions hides modal", %{conn: conn, provider: provider} do
    _listing = insert(:program_listing_schema, provider_id: provider.id)

    {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")
    assert has_element?(view, "#create-session-modal")

    view |> element("#create-session-backdrop") |> render_click()
    refute has_element?(view, "#create-session-modal")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs --only describe:"create session modal"`

Expected: FAIL — route doesn't exist yet.

- [ ] **Step 3: Add route in router**

In `lib/klass_hero_web/router.ex`, modify line 87:

```elixir
# Before:
live "/sessions", SessionsLive, :index

# After:
live "/sessions", SessionsLive, :index
live "/sessions/new", SessionsLive, :new
```

- [ ] **Step 4: Add handle_params and apply_action in SessionsLive**

Add after mount, before handle_event:

```elixir
@impl true
def handle_params(params, _url, socket) do
  {:noreply, apply_action(socket, socket.assigns.live_action, params)}
end

defp apply_action(socket, :index, _params) do
  socket
  |> assign(:show_modal, false)
  |> assign(:form, nil)
end

defp apply_action(socket, :new, _params) do
  programs = socket.assigns.provider_programs
  form_data = build_initial_form_data(socket.assigns.selected_date, programs)

  socket
  |> assign(:show_modal, true)
  |> assign(:form, to_form(form_data, as: :session))
end
```

Add helper:

```elixir
defp build_initial_form_data(selected_date, _programs) do
  %{
    "program_id" => "",
    "session_date" => Date.to_iso8601(selected_date),
    "start_time" => "",
    "end_time" => "",
    "location" => "",
    "notes" => "",
    "max_capacity" => ""
  }
end
```

Also add to mount (before `stream(:sessions, [])`):

```elixir
|> assign(:show_modal, false)
|> assign(:form, nil)
```

- [ ] **Step 5: Add minimal modal markup to template**

In `sessions_live.html.heex`, add after the closing `</div>` of the sessions stream (before the final `</div>`):

```heex
<%!-- Create Session Modal --%>
<%= if @show_modal do %>
  <div
    id="create-session-backdrop"
    class="fixed inset-0 z-50 bg-black/50"
    phx-click={JS.patch(~p"/provider/sessions")}
  >
  </div>
  <div
    id="create-session-modal"
    class={[
      "fixed inset-x-4 top-[5%] z-50 mx-auto max-w-lg",
      Theme.bg(:surface),
      Theme.rounded(:xl),
      "shadow-xl max-h-[90vh] overflow-y-auto"
    ]}
    phx-click-away={JS.patch(~p"/provider/sessions")}
  >
    <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
      <h2 class={["text-lg font-semibold", Theme.text_color(:heading)]}>
        {gettext("Create Session")}
      </h2>
      <.link
        patch={~p"/provider/sessions"}
        class="p-1 text-hero-grey-400 hover:text-hero-grey-600"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </.link>
    </div>

    <div class="p-4">
      <.form
        for={@form}
        id="create-session-form"
        phx-change="validate_session"
        phx-submit="save_session"
        class="space-y-4"
      >
        <%!-- Form fields added in Task 4 --%>
      </.form>
    </div>
  </div>
<% end %>
```

Also add the JS alias at the top of `sessions_live.ex`:

```elixir
alias Phoenix.LiveView.JS
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/router.ex lib/klass_hero_web/live/provider/sessions_live.ex lib/klass_hero_web/live/provider/sessions_live.html.heex
git commit -m "feat: add create session route and modal shell"
```

---

## Task 3: Add Form Fields to Modal Template

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.html.heex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

Note: Program loading was already done in Task 1 (mount has `provider_programs` and `provider_program_ids` assigns).

### Steps

- [ ] **Step 1: Write test for program dropdown in create form**

```elixir
test "create session form shows provider's programs in dropdown", %{
  conn: conn,
  provider: provider
} do
  listing =
    insert(:program_listing_schema,
      provider_id: provider.id,
      title: "Art Workshop"
    )

  _program = insert(:program_schema, id: listing.id, provider_id: provider.id, title: "Art Workshop")

  {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

  assert has_element?(view, "option", "Art Workshop")
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — no dropdown in form template yet.

- [ ] **Step 3: Add form fields to modal template**

In the modal form (inside `<.form>`), add:

```heex
<.input
  field={@form[:program_id]}
  type="select"
  label={gettext("Program")}
  prompt={gettext("Select a program...")}
  options={Enum.map(@provider_programs, &{&1.title, &1.id})}
  required
/>

<.input field={@form[:session_date]} type="date" label={gettext("Date")} required />

<div class="grid grid-cols-2 gap-4">
  <.input field={@form[:start_time]} type="time" label={gettext("Start Time")} required />
  <.input field={@form[:end_time]} type="time" label={gettext("End Time")} required />
</div>

<.input field={@form[:location]} type="text" label={gettext("Location")} />
<.input field={@form[:notes]} type="textarea" label={gettext("Notes")} />
<.input field={@form[:max_capacity]} type="number" label={gettext("Max Capacity")} />

<div class="flex justify-end gap-3 pt-2">
  <.link
    patch={~p"/provider/sessions"}
    class={[
      "px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50",
      Theme.rounded(:lg)
    ]}
  >
    {gettext("Cancel")}
  </.link>
  <button
    type="submit"
    class={[
      "px-4 py-2 text-sm font-medium text-white bg-hero-blue-600 hover:bg-hero-blue-700",
      Theme.rounded(:lg)
    ]}
  >
    {gettext("Create Session")}
  </button>
</div>
```

- [ ] **Step 5: Add stub event handlers to prevent crashes**

In `sessions_live.ex`, add placeholder handlers:

```elixir
@impl true
def handle_event("validate_session", %{"session" => _params}, socket) do
  {:noreply, socket}
end

@impl true
def handle_event("save_session", %{"session" => _params}, socket) do
  {:noreply, socket}
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.ex lib/klass_hero_web/live/provider/sessions_live.html.heex
git commit -m "feat: load provider programs and add form fields to create session modal"
```

---

## Task 4: Implement Program Pre-fill on Selection

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Steps

- [ ] **Step 1: Write test for pre-fill behavior**

```elixir
test "selecting a program pre-fills start_time, end_time, and location", %{
  conn: conn,
  provider: provider
} do
  listing =
    insert(:program_listing_schema,
      provider_id: provider.id,
      title: "Art Workshop",
      meeting_start_time: ~T[09:00:00],
      meeting_end_time: ~T[11:30:00],
      location: "Room 101"
    )

  _program = insert(:program_schema, id: listing.id, provider_id: provider.id)

  {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

  # Select the program
  render_change(view, "validate_session", %{
    "session" => %{
      "program_id" => listing.id,
      "session_date" => Date.to_iso8601(Date.utc_today()),
      "start_time" => "",
      "end_time" => "",
      "location" => "",
      "notes" => "",
      "max_capacity" => ""
    }
  })

  # Verify pre-filled values in form inputs
  assert has_element?(view, ~s(input[name="session[start_time]"][value="09:00"]))
  assert has_element?(view, ~s(input[name="session[end_time]"][value="11:30"]))
  assert has_element?(view, ~s(input[name="session[location]"][value="Room 101"]))
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — validate_session is a stub that doesn't pre-fill.

- [ ] **Step 3: Implement validate_session with pre-fill logic**

Replace the stub `validate_session` handler:

```elixir
@impl true
def handle_event("validate_session", %{"session" => params}, socket) do
  params = maybe_prefill_from_program(params, socket.assigns.provider_programs)

  form = to_form(params, as: :session)

  {:noreply, assign(socket, :form, form)}
end

defp maybe_prefill_from_program(params, programs) do
  program_id = params["program_id"]

  case Enum.find(programs, &(&1.id == program_id)) do
    nil ->
      params

    program ->
      # Trigger: provider selected a program from the dropdown
      # Why: pre-fill time/location from program defaults to reduce repetitive typing
      # Outcome: form fields populated; provider can override any value
      params
      |> maybe_set_default("start_time", format_time(program.meeting_start_time))
      |> maybe_set_default("end_time", format_time(program.meeting_end_time))
      |> maybe_set_default("location", program.location || "")
  end
end

# Only set if the field is currently empty — don't overwrite provider edits
defp maybe_set_default(params, key, default) do
  if params[key] in [nil, ""] do
    Map.put(params, key, default)
  else
    params
  end
end

defp format_time(nil), do: ""
defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.ex
git commit -m "feat: pre-fill session form fields when program selected"
```

---

## Task 5: Implement save_session Handler

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Steps

- [ ] **Step 1: Write test for successful session creation**

```elixir
describe "save_session" do
  setup :register_and_log_in_provider

  test "creates session and closes modal on valid submission", %{
    conn: conn,
    provider: provider
  } do
    listing =
      insert(:program_listing_schema,
        provider_id: provider.id,
        title: "Art Workshop"
      )

    program = insert(:program_schema, id: listing.id, provider_id: provider.id)

    {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

    view
    |> form("#create-session-form", %{
      "session" => %{
        "program_id" => program.id,
        "session_date" => Date.to_iso8601(Date.utc_today()),
        "start_time" => "09:00",
        "end_time" => "11:00",
        "location" => "Room 101",
        "notes" => "",
        "max_capacity" => ""
      }
    })
    |> render_submit()

    # Modal should close (redirects to :index)
    refute has_element?(view, "#create-session-modal")

    assert_flash(view, :info, "Session created successfully")
  end

  test "rejects session creation for program not owned by provider", %{
    conn: conn,
    provider: provider
  } do
    # Need at least one listing for the provider so the form renders
    _listing = insert(:program_listing_schema, provider_id: provider.id)

    other_provider = insert(:provider_profile_schema)
    other_program = insert(:program_schema, provider_id: other_provider.id)

    {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

    view
    |> form("#create-session-form", %{
      "session" => %{
        "program_id" => other_program.id,
        "session_date" => Date.to_iso8601(Date.utc_today()),
        "start_time" => "09:00",
        "end_time" => "11:00"
      }
    })
    |> render_submit()

    assert_flash(view, :error, "Unauthorized")
  end

  test "shows error for invalid time range", %{conn: conn, provider: provider} do
    listing = insert(:program_listing_schema, provider_id: provider.id)
    _program = insert(:program_schema, id: listing.id, provider_id: provider.id)

    {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

    view
    |> form("#create-session-form", %{
      "session" => %{
        "program_id" => listing.id,
        "session_date" => Date.to_iso8601(Date.utc_today()),
        "start_time" => "14:00",
        "end_time" => "10:00"
      }
    })
    |> render_submit()

    # Should stay on modal with error
    assert has_element?(view, "#create-session-modal")
    assert_flash(view, :error, "End time must be after start time")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `save_session` is still a stub.

- [ ] **Step 3: Implement save_session handler**

Replace the stub:

```elixir
@impl true
def handle_event("save_session", %{"session" => params}, socket) do
  provider_program_ids = socket.assigns.provider_program_ids

  # Trigger: provider submitted the create session form
  # Why: verify program ownership server-side — dropdown only shows their programs,
  #      but form data can be tampered with
  # Outcome: reject if program_id not in provider's set
  if MapSet.member?(provider_program_ids, params["program_id"]) do
    do_create_session(params, socket)
  else
    {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
  end
end

defp do_create_session(params, socket) do
  case coerce_session_params(params) do
    {:ok, coerced} ->
      case Participation.create_session(coerced) do
        {:ok, _session} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Session created successfully"))
           |> push_patch(to: ~p"/provider/sessions")}

        {:error, reason} ->
          Logger.error(
            "[SessionsLive.save_session] Failed to create session",
            reason: inspect(reason),
            provider_id: socket.assigns.provider_id
          )

          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Failed to create session: %{reason}", reason: humanize_error(reason))
           )}
      end

    {:error, message} ->
      {:noreply, put_flash(socket, :error, message)}
  end
end

defp coerce_session_params(params) do
  with {:ok, date} <- parse_date(params["session_date"]),
       {:ok, start_time} <- parse_time(params["start_time"]),
       {:ok, end_time} <- parse_time(params["end_time"]) do
    coerced = %{
      program_id: params["program_id"],
      session_date: date,
      start_time: start_time,
      end_time: end_time
    }

    coerced = if params["location"] not in [nil, ""], do: Map.put(coerced, :location, params["location"]), else: coerced
    coerced = if params["notes"] not in [nil, ""], do: Map.put(coerced, :notes, params["notes"]), else: coerced

    coerced =
      if params["max_capacity"] not in [nil, ""] do
        Map.put(coerced, :max_capacity, String.to_integer(params["max_capacity"]))
      else
        coerced
      end

    {:ok, coerced}
  end
end

defp parse_date(nil), do: {:error, gettext("Date is required")}
defp parse_date(""), do: {:error, gettext("Date is required")}

defp parse_date(date_string) do
  case Date.from_iso8601(date_string) do
    {:ok, _date} = ok -> ok
    {:error, _} -> {:error, gettext("Invalid date format")}
  end
end

defp parse_time(nil), do: {:error, gettext("Time is required")}
defp parse_time(""), do: {:error, gettext("Time is required")}

defp parse_time(time_string) do
  # Trigger: HTML time inputs produce "HH:MM" without seconds
  # Why: Time.from_iso8601/1 requires "HH:MM:SS" format
  # Outcome: append ":00" seconds for successful parsing
  normalized = if String.length(time_string) == 5, do: time_string <> ":00", else: time_string

  case Time.from_iso8601(normalized) do
    {:ok, _time} = ok -> ok
    {:error, _} -> {:error, gettext("Invalid time format")}
  end
end

defp humanize_error(:invalid_time_range), do: gettext("End time must be after start time")
defp humanize_error(:duplicate_session), do: gettext("A session already exists at this time")
defp humanize_error(:missing_required_fields), do: gettext("Please fill in all required fields")
defp humanize_error(reason), do: inspect(reason)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.ex test/klass_hero_web/live/provider/sessions_live_test.exs
git commit -m "feat: implement create session form submission with validation"
```

---

## Task 6: Add session_created to PubSub Handler (Real-Time Update)

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Background

The `session_created` event type was already added to the `handle_info` guard in Task 1 (`:session_created` is in the `when` clause). This task adds a test to verify the full flow: create session → PubSub event → session appears in stream.

### Steps

- [ ] **Step 1: Write test for session appearing in stream after creation**

```elixir
test "created session appears in stream for the selected date", %{
  conn: conn,
  provider: provider
} do
  listing =
    insert(:program_listing_schema,
      provider_id: provider.id,
      title: "Art Workshop"
    )

  program = insert(:program_schema, id: listing.id, provider_id: provider.id)

  {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

  # Initially empty
  refute has_element?(view, "button", "Start Session")

  view
  |> form("#create-session-form", %{
    "session" => %{
      "program_id" => program.id,
      "session_date" => Date.to_iso8601(Date.utc_today()),
      "start_time" => "09:00",
      "end_time" => "11:00"
    }
  })
  |> render_submit()

  # After PubSub event processes, session should appear with Start button
  assert has_element?(view, "button", "Start Session")
end
```

- [ ] **Step 2: Write test for date filtering on session_created**

```elixir
test "created session does NOT appear when viewing a different date", %{
  conn: conn,
  provider: provider
} do
  listing = insert(:program_listing_schema, provider_id: provider.id)
  program = insert(:program_schema, id: listing.id, provider_id: provider.id)

  tomorrow = Date.add(Date.utc_today(), 1)

  {:ok, view, _html} = live(conn, ~p"/provider/sessions/new")

  view
  |> form("#create-session-form", %{
    "session" => %{
      "program_id" => program.id,
      "session_date" => Date.to_iso8601(tomorrow),
      "start_time" => "09:00",
      "end_time" => "11:00"
    }
  })
  |> render_submit()

  # Session is for tomorrow but we're viewing today — should NOT appear
  refute has_element?(view, "button", "Start Session")
end
```

- [ ] **Step 3: Add date check to session_created handler**

The combined handler from Task 1 handles `:session_created`, `:session_started`, and `:session_completed` uniformly. For `session_created`, we need an additional date filter. Update the handler:

```elixir
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
    when event_type in [:session_started, :session_completed, :session_created] do
  if MapSet.member?(socket.assigns.provider_program_ids, payload.program_id) do
    # Trigger: session_created events may be for a date the provider isn't currently viewing
    # Why: the stream only shows sessions for selected_date; inserting a wrong-date session
    #      would pollute the current view
    # Outcome: for session_created, also check date; start/complete are for existing stream items
    if event_type == :session_created and Map.get(payload, :session_date) != socket.assigns.selected_date do
      {:noreply, socket}
    else
      {:noreply, update_session_in_stream(socket, session_id)}
    end
  else
    {:noreply, socket}
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.ex test/klass_hero_web/live/provider/sessions_live_test.exs
git commit -m "feat: add date filtering for session_created PubSub events"
```

---

## Task 7: Add Create Session Button to Page

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.html.heex`
- Test: `test/klass_hero_web/live/provider/sessions_live_test.exs`

### Steps

- [ ] **Step 1: Write test for create button visibility**

```elixir
test "shows 'Create Session' button on sessions page", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/provider/sessions")

  assert has_element?(view, ~s(a[href="/provider/sessions/new"]), "Create Session")
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — no button in template yet.

- [ ] **Step 3: Add Create Session button to page header**

In `sessions_live.html.heex`, modify the page header section:

```heex
<%!-- Page header --%>
<div class="mb-6 flex items-center justify-between">
  <.page_header>
    <:title>My Sessions</:title>
    <:subtitle>Manage your scheduled sessions and attendance</:subtitle>
  </.page_header>
  <.link
    patch={~p"/provider/sessions/new"}
    class={[
      "px-4 py-2 text-sm font-medium text-white bg-hero-blue-600 hover:bg-hero-blue-700 focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2",
      Theme.rounded(:lg),
      Theme.transition(:normal)
    ]}
  >
    <.icon name="hero-plus" class="w-4 h-4 mr-1 inline" />
    {gettext("Create Session")}
  </.link>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/sessions_live.html.heex test/klass_hero_web/live/provider/sessions_live_test.exs
git commit -m "feat: add 'Create Session' button to provider sessions page"
```

---

## Task 8: Run Precommit and File Follow-Up Issue

**Files:** None (quality gate + issue creation)

### Steps

- [ ] **Step 1: Run precommit checks**

```bash
mix precommit
```

Expected: All checks pass (compile with warnings-as-errors, format, test).

- [ ] **Step 2: Fix any warnings or test failures**

Address any issues found by precommit. Re-run until clean.

- [ ] **Step 3: File follow-up issue for provider-specific PubSub topic routing**

```bash
gh issue create --title "[TASK] Migrate SessionsLive PubSub to provider-specific topic routing" \
  --body "## Background

SessionsLive currently subscribes to generic event topics (\`participation:session_created\`, etc.) and filters by provider_id client-side. This works but leaks domain logic into the LiveView.

## Goal

Add provider-specific topic routing in the event handler layer so SessionsLive subscribes to \`participation:provider:\${provider_id}\` and receives only relevant events.

## References

- Design spec: \`docs/superpowers/specs/2026-03-18-provider-create-session-design.md\` (Follow-up section)
- Current implementation: \`lib/klass_hero_web/live/provider/sessions_live.ex\`
- Event handler: \`lib/klass_hero/shared/adapters/driven/events/event_handlers/notify_live_views.ex\`" \
  --label "enhancement,backend"
```

- [ ] **Step 4: Commit any formatting fixes from precommit**

Stage any files modified by `mix format` and commit:

```bash
git commit -am "chore: apply formatting from precommit"
```

(Skip if precommit made no changes.)
