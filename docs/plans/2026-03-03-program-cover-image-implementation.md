# Program Cover Image Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix issue #196 — wire up cover image display on program cards and detail page, fix upload error UX to show warning flash instead of aborting save.

**Architecture:** The `cover_image_url` field already flows through domain model → Ecto schema → read model → persistence mapper. The upload pipeline (`allow_upload(:program_cover, ...)`, `consume_single_upload/4`, `upload_program_cover/2`) is complete. Changes are display-side wiring + upload error UX.

**Tech Stack:** Phoenix LiveView 1.1, HEEx templates, Tailwind CSS, ExMachina factories

---

### Task 1: Wire cover_image_url into program_to_map

**Files:**
- Modify: `lib/klass_hero_web/live/programs_live.ex:112-127`

**Step 1: Add cover_image_url to the map**

In `program_to_map/2`, add `cover_image_url` to the returned map after `spots_left`:

```elixir
# In the %{ ... } map at line 112-127, add after line 123:
      cover_image_url: program.cover_image_url,
```

The full map becomes:

```elixir
%{
  id: program.id,
  title: program.title,
  description: program.description,
  category: format_category_for_display(program.category),
  meeting_days: program.meeting_days || [],
  meeting_start_time: program.meeting_start_time,
  meeting_end_time: program.meeting_end_time,
  age_range: program.age_range,
  price: safe_decimal_to_float(program.price),
  period: program.pricing_period,
  spots_left: spots_left,
  cover_image_url: program.cover_image_url,
  # Default UI properties (these will come from the database in the future)
  gradient_class: default_gradient_class(),
  icon_name: ProgramPresenter.icon_name(program.category)
}
```

**Step 2: Compile to verify**

Run: `mix compile --warnings-as-errors`
Expected: SUCCESS, no warnings

**Step 3: Commit**

```bash
git add lib/klass_hero_web/live/programs_live.ex
git commit -m "fix: include cover_image_url in programs listing map"
```

---

### Task 2: Update program_card component to render cover image

**Files:**
- Modify: `lib/klass_hero_web/components/program_components.ex:254-293`

**Step 1: Write the failing test**

Create test file `test/klass_hero_web/components/program_card_cover_image_test.exs`:

```elixir
defmodule KlassHeroWeb.ProgramCardCoverImageTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.ProgramComponents

  @base_program %{
    id: "test-123",
    title: "Art Adventures",
    description: "Explore creativity",
    category: "Arts",
    meeting_days: ["Monday"],
    meeting_start_time: ~T[15:00:00],
    meeting_end_time: ~T[17:00:00],
    age_range: "6-8 years",
    price: 120.0,
    period: "per month",
    spots_left: nil,
    gradient_class: "bg-gradient-to-br from-hero-blue-400 to-hero-blue-600",
    icon_name: "hero-paint-brush",
    cover_image_url: nil,
    is_online: false
  }

  describe "program_card cover image" do
    test "renders cover image when cover_image_url is present" do
      program = Map.put(@base_program, :cover_image_url, "https://example.com/cover.jpg")
      html = render_component(&ProgramComponents.program_card/1, program: program)

      assert html =~ ~s(src="https://example.com/cover.jpg")
      assert html =~ "object-cover"
      # Icon should NOT be rendered when cover image is present
      refute html =~ "hero-paint-brush"
    end

    test "renders gradient fallback when cover_image_url is nil" do
      html = render_component(&ProgramComponents.program_card/1, program: @base_program)

      refute html =~ "<img"
      assert html =~ "bg-gradient-to-br"
      assert html =~ "hero-paint-brush"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/components/program_card_cover_image_test.exs -v`
Expected: FAIL — cover image `<img>` not rendered

**Step 3: Implement the cover image display**

In `program_components.ex`, replace the card header section (lines 254-293) with conditional rendering:

```heex
    <!-- Program Image/Header -->
    <%= if Map.get(@program, :cover_image_url) do %>
      <%!-- Cover image fills header, no icon --%>
      <div class="h-48 relative overflow-hidden">
        <img
          src={@program.cover_image_url}
          alt={@program.title}
          class="w-full h-full object-cover"
        />

        <%!-- Category Badge (top-left) --%>
        <div :if={Map.get(@program, :category)} class="absolute top-4 left-4 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-white/90 text-hero-black backdrop-blur-sm",
            Theme.rounded(:full)
          ]}>
            {@program.category}
          </span>
        </div>

        <%!-- ONLINE Badge --%>
        <div :if={Map.get(@program, :is_online, false)} class="absolute top-4 left-4 mt-10 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-hero-blue-600 text-white",
            Theme.rounded(:full)
          ]}>
            ONLINE
          </span>
        </div>

        <%!-- Spots Left Badge (bottom-left) --%>
        <.spots_badge
          :if={@program.spots_left && @program.spots_left <= 5}
          spots_left={@program.spots_left}
        />
      </div>
    <% else %>
      <%!-- Gradient fallback with icon when no cover image --%>
      <div class={["h-48 relative overflow-hidden", @program.gradient_class]}>
        <div class="absolute inset-0 bg-black/10"></div>

        <%!-- Category Badge (top-left) --%>
        <div :if={Map.get(@program, :category)} class="absolute top-4 left-4 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-white/90 text-hero-black backdrop-blur-sm",
            Theme.rounded(:full)
          ]}>
            {@program.category}
          </span>
        </div>

        <%!-- ONLINE Badge --%>
        <div :if={Map.get(@program, :is_online, false)} class="absolute top-4 left-4 mt-10 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-hero-blue-600 text-white",
            Theme.rounded(:full)
          ]}>
            ONLINE
          </span>
        </div>

        <%!-- Spots Left Badge (bottom-left) --%>
        <.spots_badge
          :if={@program.spots_left && @program.spots_left <= 5}
          spots_left={@program.spots_left}
        />

        <%!-- Program Icon --%>
        <div class="absolute inset-0 flex items-center justify-center">
          <div class={[
            "w-16 h-16 bg-white/20 backdrop-blur-sm flex items-center justify-center",
            Theme.rounded(:full)
          ]}>
            <.icon name={@program.icon_name} class="w-8 h-8 text-white" />
          </div>
        </div>
      </div>
    <% end %>
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/components/program_card_cover_image_test.exs -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/klass_hero_web/components/program_components.ex test/klass_hero_web/components/program_card_cover_image_test.exs
git commit -m "feat: render cover image on program card with gradient fallback"
```

---

### Task 3: Update program detail hero to render cover image

**Files:**
- Modify: `lib/klass_hero_web/live/program_detail_live.ex:162-228`

**Step 1: Write the failing test**

Add to `test/klass_hero_web/live/program_detail_live_test.exs`:

```elixir
describe "ProgramDetailLive cover image" do
  test "renders cover image in hero when cover_image_url is present", %{conn: conn} do
    program =
      insert(:program_schema,
        title: "Painting Class",
        cover_image_url: "https://example.com/painting.jpg"
      )

    {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

    assert has_element?(view, "img[src='https://example.com/painting.jpg']")
  end

  test "renders gradient hero when no cover image", %{conn: conn} do
    program = insert(:program_schema, title: "Chess Club", cover_image_url: nil)
    {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

    refute has_element?(view, "#program-hero-image")
    assert has_element?(view, "#program-hero")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/program_detail_live_test.exs --only describe:"ProgramDetailLive cover image" -v`
Expected: FAIL — no `<img>` in hero

**Step 3: Implement the hero cover image**

In `program_detail_live.ex`, replace the hero section (lines 162-228). The outer `<div>` gets an `id="program-hero"` for testability:

```heex
    <%!-- Hero Section --%>
    <%= if @program.cover_image_url do %>
      <div id="program-hero" class="relative">
        <img
          id="program-hero-image"
          src={@program.cover_image_url}
          alt={@program.title}
          class="w-full h-64 sm:h-80 object-cover"
        />
        <%!-- Subtle bottom gradient for text readability --%>
        <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>

        <%!-- Navigation Bar --%>
        <div class="absolute top-0 left-0 right-0 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pt-4">
          <div class="flex items-center justify-between">
            <.back_button phx-click="back_to_programs" />
          </div>
        </div>

        <%!-- Program Title & Info (Bottom of Hero) --%>
        <div class="absolute bottom-0 left-0 right-0 pb-8 px-4">
          <div class="max-w-4xl mx-auto text-center text-white">
            <h1 class={[Theme.typography(:page_title), "mb-3"]}>
              {@program.title}
            </h1>
            <div class="flex flex-wrap items-center justify-center gap-4 text-sm text-white/90 mb-4">
              <%= if schedule = ProgramPresenter.format_schedule(@program) do %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  <%= if schedule.days do %>
                    {schedule.days}
                    <%= if schedule.times do %>
                      <span class="mx-1">&middot;</span>
                      {schedule.times}
                    <% end %>
                  <% else %>
                    {schedule.times}
                  <% end %>
                </span>
              <% else %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  {gettext("Schedule TBD")}
                </span>
              <% end %>
              <span :if={@program.age_range} class="flex items-center">
                <.icon name="hero-user-group" class="w-4 h-4 mr-1" />
                {gettext("Ages %{range}", range: @program.age_range)}
              </span>
              <span :if={@program.location} class="flex items-center">
                <.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> {@program.location}
              </span>
            </div>
            <%!-- Badges --%>
            <div class="flex flex-wrap justify-center gap-2">
              <span class={[
                "px-3 py-1 text-xs font-medium bg-white/90 backdrop-blur-sm text-green-700",
                Theme.rounded(:full)
              ]}>
                {gettext("✓ No hidden fees")}
              </span>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <div id="program-hero" class={["relative", Theme.gradient(:hero)]}>
        <div class="absolute inset-0 bg-black/20"></div>

        <%!-- Navigation Bar --%>
        <div class="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pt-4">
          <div class="flex items-center justify-between">
            <.back_button phx-click="back_to_programs" />
          </div>
        </div>

        <%!-- Program Icon --%>
        <div class="relative flex justify-center py-6">
          <div class={[
            "w-20 h-20 bg-white/20 backdrop-blur-sm flex items-center justify-center",
            Theme.rounded(:full)
          ]}>
            <.icon name={@program_icon_name} class="w-10 h-10 text-white" />
          </div>
        </div>

        <%!-- Program Title & Info (Centered in Hero) --%>
        <div class="relative pb-12 px-4">
          <div class="max-w-4xl mx-auto text-center text-white">
            <h1 class={[Theme.typography(:page_title), "mb-3"]}>
              {@program.title}
            </h1>
            <div class="flex flex-wrap items-center justify-center gap-4 text-sm text-white/90 mb-4">
              <%= if schedule = ProgramPresenter.format_schedule(@program) do %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  <%= if schedule.days do %>
                    {schedule.days}
                    <%= if schedule.times do %>
                      <span class="mx-1">&middot;</span>
                      {schedule.times}
                    <% end %>
                  <% else %>
                    {schedule.times}
                  <% end %>
                </span>
              <% else %>
                <span class="flex items-center">
                  <.icon name="hero-clock" class="w-4 h-4 mr-1" />
                  {gettext("Schedule TBD")}
                </span>
              <% end %>
              <span :if={@program.age_range} class="flex items-center">
                <.icon name="hero-user-group" class="w-4 h-4 mr-1" />
                {gettext("Ages %{range}", range: @program.age_range)}
              </span>
              <span :if={@program.location} class="flex items-center">
                <.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> {@program.location}
              </span>
            </div>
            <%!-- Badges --%>
            <div class="flex flex-wrap justify-center gap-2">
              <span class={[
                "px-3 py-1 text-xs font-medium bg-white/90 backdrop-blur-sm text-green-700",
                Theme.rounded(:full)
              ]}>
                {gettext("✓ No hidden fees")}
              </span>
            </div>
          </div>
        </div>
      </div>
    <% end %>
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/program_detail_live_test.exs -v`
Expected: PASS (all tests including existing ones)

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/program_detail_live.ex test/klass_hero_web/live/program_detail_live_test.exs
git commit -m "feat: render cover image in program detail hero with gradient fallback"
```

---

### Task 4: Fix upload error handling — flash warning, save anyway

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex:689-730, 1559-1569`

**Step 1: Change save_program to pass upload errors through**

Replace the `save_program` handler (lines 689-730). Remove the early `:upload_error` abort. All upload results now flow through to `maybe_add_cover_image/2`:

```elixir
def handle_event("save_program", %{"program_schema" => params} = all_params, socket) do
  provider = socket.assigns.current_scope.provider

  # Trigger: cover image upload may succeed, be absent, or fail
  # Why: upload failures should warn but not block program save
  # Outcome: all results flow through; cover_failed flag tracks warning
  cover_result = upload_program_cover(socket, provider.id)

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
      end_date: parse_date(params["end_date"]),
      registration_start_date: parse_date(params["registration_start_date"]),
      registration_end_date: parse_date(params["registration_end_date"])
    }
    |> maybe_add_cover_image(cover_result)

  # Trigger: editing_program_id is nil for new programs, a UUID for edits
  # Why: reuse the same form and submit handler for both create and edit
  # Outcome: dispatch to create_new_program or update_existing_program
  socket =
    case socket.assigns.editing_program_id do
      nil ->
        create_new_program(socket, attrs, all_params)

      program_id ->
        update_existing_program(socket, program_id, attrs, all_params)
    end

  # Trigger: cover upload failed but program save may have succeeded
  # Why: user chose "save anyway" behavior — warn but don't block
  # Outcome: append warning flash if cover upload failed
  socket =
    if cover_result == :upload_error do
      put_flash(socket, :warning, gettext("Program saved, but the cover image upload failed. You can re-upload it by editing the program."))
    else
      socket
    end

  {:noreply, socket}
end
```

**Important:** This requires `create_new_program/3` and `update_existing_program/4` to return the socket directly instead of `{:noreply, socket}`. Check current return values first — if they already return `{:noreply, socket}`, you'll need to extract the socket. Alternatively, keep the current structure and add the cover warning flash inside `create_new_program` and `update_existing_program` by passing `cover_result` as an additional argument.

**Simpler approach — pass cover_result through:**

Actually, looking at the current code more carefully, `create_new_program` returns `{:noreply, socket}` tuples. The simplest change is to just remove the `:upload_error` early-abort clause and let `maybe_add_cover_image/2` handle it (it already does — logs warning and returns attrs without cover). Then add the flash warning inside `maybe_add_cover_image/2` won't work because it doesn't have the socket.

**Final approach:** The cleanest change is minimal:

1. Remove the `:upload_error ->` early-abort clause (lines 696-698)
2. Update the comment at line 692-694
3. Update `maybe_add_cover_image(attrs, :upload_error)` to just return attrs (remove the Logger.warning since it's now expected behavior)
4. After the `case socket.assigns.editing_program_id` block, the `{:noreply, socket}` is returned by the inner functions. To add a flash, track `cover_result` and add the warning flash in `create_new_program` and `update_existing_program`.

Actually, the simplest correct approach: pass `cover_result` as a 4th/5th arg to `create_new_program`/`update_existing_program`, and have them add the warning flash on success when `cover_result == :upload_error`.

**Step 2: Implementation**

In `save_program/2` (line 689-730), replace:

```elixir
def handle_event("save_program", %{"program_schema" => params} = all_params, socket) do
  provider = socket.assigns.current_scope.provider

  # Trigger: cover image upload may succeed, be absent, or fail
  # Why: upload failures warn but don't block program save
  # Outcome: all results flow through; cover_failed appends warning flash after save
  cover_result = upload_program_cover(socket, provider.id)

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
      end_date: parse_date(params["end_date"]),
      registration_start_date: parse_date(params["registration_start_date"]),
      registration_end_date: parse_date(params["registration_end_date"])
    }
    |> maybe_add_cover_image(cover_result)

  # Trigger: editing_program_id is nil for new programs, a UUID for edits
  # Why: reuse the same form and submit handler for both create and edit
  # Outcome: dispatch to create_new_program or update_existing_program
  case socket.assigns.editing_program_id do
    nil ->
      create_new_program(socket, attrs, all_params, cover_result)

    program_id ->
      update_existing_program(socket, program_id, attrs, all_params, cover_result)
  end
end
```

In `create_new_program` (line 756), add `cover_result` param and warning flash on success:

```elixir
defp create_new_program(socket, attrs, all_params, cover_result) do
  # ... existing code unchanged until the success branch (line 773) ...
  # After flash_for_policy_result, add:
  |> maybe_flash_cover_warning(cover_result)
  # ... rest unchanged ...
end
```

In `update_existing_program` (line 805), same pattern:

```elixir
defp update_existing_program(socket, program_id, attrs, all_params, cover_result) do
  # ... existing code unchanged until the success branch (line 824) ...
  # After put_flash(:info, ...), add:
  |> maybe_flash_cover_warning(cover_result)
  # ... rest unchanged ...
end
```

Add new helper:

```elixir
defp maybe_flash_cover_warning(socket, :upload_error) do
  put_flash(socket, :warning, gettext("Program saved, but the cover image upload failed. You can re-upload it by editing the program."))
end

defp maybe_flash_cover_warning(socket, _cover_result), do: socket
```

Clean up `maybe_add_cover_image/2` for `:upload_error` — remove Logger.warning:

```elixir
defp maybe_add_cover_image(attrs, :upload_error), do: attrs
```

**Step 3: Compile to verify**

Run: `mix compile --warnings-as-errors`
Expected: SUCCESS

**Step 4: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "fix: show warning flash on cover upload failure instead of blocking save"
```

---

### Task 5: Add cover image test for programs listing

**Files:**
- Modify: `test/klass_hero_web/live/programs_live_test.exs`

**Step 1: Write the test**

Add to the existing describe block:

```elixir
test "displays cover image on program card when cover_image_url is present", %{conn: conn} do
  insert_program(%{
    title: "Swimming Lessons",
    cover_image_url: "https://example.com/swimming.jpg"
  })

  {:ok, view, _html} = live(conn, ~p"/programs")

  assert has_element?(view, "img[src='https://example.com/swimming.jpg']")
end

test "displays gradient fallback when program has no cover image", %{conn: conn} do
  insert_program(%{title: "Chess Club", cover_image_url: nil})

  {:ok, view, _html} = live(conn, ~p"/programs")

  # No <img> should be rendered in the card header for this program
  refute has_element?(view, "img[src]")
end
```

**Step 2: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/programs_live_test.exs -v`
Expected: PASS (these should pass immediately since Task 1 + Task 2 already wired it up)

**Step 3: Commit**

```bash
git add test/klass_hero_web/live/programs_live_test.exs
git commit -m "test: add cover image display tests for programs listing"
```

---

### Task 6: Run precommit and verify

**Step 1: Run full precommit checks**

Run: `mix precommit`
Expected: compile (0 warnings), format (clean), test (all pass)

**Step 2: Fix any issues found**

If warnings or test failures, fix them.

**Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address precommit findings"
```
