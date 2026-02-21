# Family Programs Dashboard Section Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display a parent's enrolled programs as cards on the dashboard, sorted by upcoming session date, with expired programs greyed out at the bottom.

**Architecture:** Extend `DashboardLive` mount to fetch enrollments via existing `Enrollment.list_parent_enrollments/1` and programs via `ProgramCatalog.get_program_by_id/1`. Extend `<.program_card>` with optional `expired` and `contact_url` attrs. Add session date range display. No new backend use cases needed.

**Tech Stack:** Phoenix LiveView 1.1, Tailwind CSS, existing Enrollment + ProgramCatalog contexts

---

### Task 1: Add `to_card_view/1` to ProgramPresenter

Transforms a `Program.t()` domain model into the map format that `<.program_card>` expects, without mock data enrichment.

**Files:**
- Modify: `lib/klass_hero_web/presenters/program_presenter.ex`
- Test: `test/klass_hero_web/presenters/program_presenter_test.exs`

**Step 1: Write failing test**

Create `test/klass_hero_web/presenters/program_presenter_test.exs` and add a test for `to_card_view/1`:

```elixir
defmodule KlassHeroWeb.Presenters.ProgramPresenterTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHeroWeb.Presenters.ProgramPresenter

  describe "to_card_view/1" do
    test "transforms program domain model to card-ready map" do
      program = %Program{
        id: "prog-1",
        provider_id: "prov-1",
        title: "Art Adventures",
        description: "Creative art for kids",
        category: "arts",
        age_range: "6-12",
        price: Decimal.new("15.00"),
        pricing_period: "session",
        icon_path: "M12 6v6m0 0v6m0-6h6m-6 0H6",
        meeting_days: ["Monday", "Wednesday"],
        meeting_start_time: ~T[15:00:00],
        meeting_end_time: ~T[16:30:00],
        start_date: ~D[2026-03-01],
        end_date: ~D[2026-06-30]
      }

      result = ProgramPresenter.to_card_view(program)

      assert result.id == "prog-1"
      assert result.title == "Art Adventures"
      assert result.description == "Creative art for kids"
      assert result.category == "Arts"
      assert result.age_range == "6-12"
      assert result.icon_path == "M12 6v6m0 0v6m0-6h6m-6 0H6"
      assert result.meeting_days == ["Monday", "Wednesday"]
      assert result.meeting_start_time == ~T[15:00:00]
      assert result.meeting_end_time == ~T[16:30:00]
      assert result.start_date == ~D[2026-03-01]
      assert result.end_date == ~D[2026-06-30]
      assert is_binary(result.gradient_class)
      assert result.spots_left == nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/presenters/program_presenter_test.exs -v`
Expected: FAIL — `to_card_view/1` undefined

**Step 3: Implement `to_card_view/1`**

Add to `lib/klass_hero_web/presenters/program_presenter.ex` after the existing `to_table_view/2` function (~line 55):

```elixir
@doc """
Transforms a Program domain model to card view format.

Used for the parent dashboard's Family Programs section and anywhere
`<.program_card>` is rendered from real domain data.

Returns a map matching the attrs expected by `ProgramComponents.program_card/1`.
"""
@spec to_card_view(Program.t()) :: map()
def to_card_view(%Program{} = program) do
  %{
    id: program.id,
    title: program.title,
    description: program.description,
    category: humanize_category(program.category),
    age_range: program.age_range,
    price: program.price |> Decimal.round(2) |> Decimal.to_string(),
    period: program.pricing_period,
    icon_path: program.icon_path || default_icon_path(),
    gradient_class: default_gradient_class(),
    meeting_days: program.meeting_days || [],
    meeting_start_time: program.meeting_start_time,
    meeting_end_time: program.meeting_end_time,
    start_date: program.start_date,
    end_date: program.end_date,
    spots_left: nil
  }
end

defp default_gradient_class do
  "bg-gradient-to-br from-hero-blue-400 to-hero-blue-600"
end

defp default_icon_path do
  "M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/presenters/program_presenter_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero_web/presenters/program_presenter.ex test/klass_hero_web/presenters/program_presenter_test.exs
git commit -m "feat: add to_card_view/1 to ProgramPresenter (#154)"
```

---

### Task 2: Extend `<.program_card>` with `expired` and `contact_url` attrs

Add optional attributes to the existing component for expired styling and contact link.

**Files:**
- Modify: `lib/klass_hero_web/components/program_components.ex:231-437`

**Step 1: Add attrs**

After line 235 (`attr :class, :string, default: ""`) add:

```elixir
attr :expired, :boolean, default: false, doc: "Greyed-out styling for expired programs"
attr :contact_url, :string, default: nil, doc: "URL for contact button (e.g. /messages)"
```

**Step 2: Apply expired styling to root div**

Change the root `<div>` class list (line 241-248) to include expired opacity:

```elixir
<div
  class={[
    "bg-white shadow-sm border border-hero-grey-100",
    Theme.rounded(:xl),
    if(@expired,
      do: "opacity-60 grayscale",
      else: "hover:shadow-lg hover:scale-[1.02]"
    ),
    Theme.transition(:slow),
    "overflow-hidden cursor-pointer",
    @class
  ]}
  {@rest}
>
```

**Step 3: Add contact button in the card footer**

After the Price section closing `</div>` (line 433), before the final `</div>` (line 434), add:

```heex
<%!-- Contact Button --%>
<div :if={@contact_url} class="px-6 pb-6">
  <.link
    navigate={@contact_url}
    class={[
      "block w-full text-center px-4 py-2 text-sm font-medium",
      Theme.rounded(:lg),
      "bg-hero-blue-50 text-hero-blue-600 hover:bg-hero-blue-100",
      Theme.transition(:normal)
    ]}
    onclick="event.stopPropagation();"
  >
    <.icon name="hero-chat-bubble-left-right-mini" class="w-4 h-4 inline mr-1" />
    {gettext("Contact Provider")}
  </.link>
</div>
```

**Step 4: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS (no warnings)

**Step 5: Commit**

```bash
git add lib/klass_hero_web/components/program_components.ex
git commit -m "feat: add expired and contact_url attrs to program_card (#154)"
```

---

### Task 3: Add `<.program_card>` session date range display

Show `start_date` - `end_date` range on the card when available.

**Files:**
- Modify: `lib/klass_hero_web/components/program_components.ex` (inside `program_card`)

**Step 1: Add date range display**

After the schedule line (line 413) and before the age range line (line 414), add a date range row:

```heex
<div
  :if={Map.get(@program, :start_date)}
  class="flex items-center text-sm text-hero-black-100"
>
  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-width="2"
      d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
    />
  </svg>
  {ProgramPresenter.format_date_range_brief(@program)}
</div>
```

**Step 2: Add `format_date_range_brief/1` to ProgramPresenter**

Add to `lib/klass_hero_web/presenters/program_presenter.ex`:

```elixir
@doc """
Formats a brief date range string from any map with :start_date and :end_date keys.

Returns a string like "Mar 1 - Jun 30, 2026" or nil if no start_date.
"""
@spec format_date_range_brief(map()) :: String.t() | nil
def format_date_range_brief(program) when is_map(program) do
  start_date = Map.get(program, :start_date)
  end_date = Map.get(program, :end_date)
  format_date_range(start_date, end_date)
end
```

**Step 3: Add test for `format_date_range_brief/1`**

In `test/klass_hero_web/presenters/program_presenter_test.exs`:

```elixir
describe "format_date_range_brief/1" do
  test "formats date range from map" do
    program = %{start_date: ~D[2026-03-01], end_date: ~D[2026-06-30]}
    assert ProgramPresenter.format_date_range_brief(program) == "Mar 1 - Jun 30, 2026"
  end

  test "returns nil when no start_date" do
    assert ProgramPresenter.format_date_range_brief(%{start_date: nil, end_date: nil}) == nil
  end
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero_web/presenters/program_presenter_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero_web/components/program_components.ex lib/klass_hero_web/presenters/program_presenter.ex test/klass_hero_web/presenters/program_presenter_test.exs
git commit -m "feat: add session date range display to program_card (#154)"
```

---

### Task 4: Load enrolled programs in DashboardLive

Fetch enrollments + programs in mount, split active/expired, assign to socket.

**Files:**
- Modify: `lib/klass_hero_web/live/dashboard_live.ex:14-36` (mount function)

**Step 1: Add helper to load family programs**

Add private functions after the existing helpers in `dashboard_live.ex`:

```elixir
alias KlassHero.ProgramCatalog

defp load_family_programs(identity_id) do
  enrollments = Enrollment.list_parent_enrollments(identity_id)

  # Trigger: each enrollment references a program_id
  # Why: we need full program data for card rendering (title, schedule, etc.)
  # Outcome: list of {enrollment, program} tuples, dropping any where program is not found
  enrollment_programs =
    enrollments
    |> Enum.map(fn enrollment ->
      case ProgramCatalog.get_program_by_id(enrollment.program_id) do
        {:ok, program} -> {enrollment, program}
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

  today = Date.utc_today()

  {active, expired} =
    Enum.split_with(enrollment_programs, fn {enrollment, program} ->
      not expired?(enrollment, program, today)
    end)

  # Trigger: active sorted by soonest upcoming session; expired by most recent end date
  # Why: parents want to see what's coming next first
  # Outcome: active ascending by start_date, expired descending by end_date
  active_sorted = Enum.sort_by(active, fn {_e, p} -> p.start_date || ~D[9999-12-31] end, Date)

  expired_sorted =
    Enum.sort_by(expired, fn {_e, p} -> p.end_date || ~D[0001-01-01] end, {:desc, Date})

  {active_sorted, expired_sorted}
end

# Trigger: enrollment completed/cancelled OR program end date passed
# Why: both conditions indicate the program is no longer active for this family
# Outcome: returns true if the enrollment should appear in the expired section
defp expired?(%{status: status}, _program, _today) when status in [:completed, :cancelled],
  do: true

defp expired?(_enrollment, %{end_date: end_date}, today) when not is_nil(end_date),
  do: Date.compare(end_date, today) == :lt

defp expired?(_enrollment, _program, _today), do: false
```

**Step 2: Update mount to call loader and assign**

In mount (line 21-33), add after `referral_stats` assign and before `|> stream(:children, ...)`:

```elixir
{active_programs, expired_programs} = load_family_programs(user.id)
```

And add to the assign block:

```elixir
family_programs_active: active_programs,
family_programs_expired: expired_programs,
family_programs_empty?: active_programs == [] and expired_programs == [],
```

**Step 3: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/klass_hero_web/live/dashboard_live.ex
git commit -m "feat: load enrolled programs in DashboardLive mount (#154)"
```

---

### Task 5: Add Family Programs section to dashboard template

Render the new section between Family Achievements and Recommended Programs.

**Files:**
- Modify: `lib/klass_hero_web/live/dashboard_live.ex:208-211` (template, after Family Achievements section)

**Step 1: Add template section**

After the Family Achievements `</section>` (line 211) and before the Recommended Programs comment (line 212), add:

```heex
<%!-- Family Programs --%>
<section id="family-programs" class="mb-8">
  <div class="flex items-center gap-2 mb-4">
    <.icon name="hero-academic-cap-mini" class="w-6 h-6 text-hero-cyan" />
    <h2 class="text-xl font-semibold text-hero-charcoal">
      {gettext("Family Programs")}
    </h2>
  </div>

  <%= if @family_programs_empty? do %>
    <div id="family-programs-empty" class="text-center py-12 bg-white rounded-2xl shadow-sm">
      <.icon name="hero-book-open" class="w-12 h-12 text-hero-grey-300 mx-auto mb-4" />
      <p class="text-hero-grey-500 mb-4">
        {gettext("No programs booked yet")}
      </p>
      <.link
        navigate={~p"/programs"}
        class={[
          "inline-flex items-center px-6 py-3 text-white font-medium",
          "bg-hero-blue-600 hover:bg-hero-blue-700",
          Theme.rounded(:lg),
          Theme.transition(:normal)
        ]}
      >
        {gettext("Book a Program")}
      </.link>
    </div>
  <% else %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <.program_card
        :for={{enrollment, program} <- @family_programs_active}
        id={"family-program-#{enrollment.id}"}
        program={ProgramPresenter.to_card_view(program)}
        variant={:detailed}
        show_favorite={false}
        contact_url={~p"/messages"}
        phx-click="program_click"
        phx-value-program-id={program.id}
      />
      <.program_card
        :for={{enrollment, program} <- @family_programs_expired}
        id={"family-program-#{enrollment.id}"}
        program={ProgramPresenter.to_card_view(program)}
        variant={:detailed}
        show_favorite={false}
        expired={true}
        phx-click="program_click"
        phx-value-program-id={program.id}
      />
    </div>
  <% end %>
</section>
```

**Step 2: Add ProgramComponents import**

At the top of `dashboard_live.ex` (after line 6), add:

```elixir
import KlassHeroWeb.ProgramComponents, only: [program_card: 1]
```

**Step 3: Run compile check**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/klass_hero_web/live/dashboard_live.ex
git commit -m "feat: add Family Programs section to dashboard template (#154)"
```

---

### Task 6: Write LiveView tests for Family Programs section

**Files:**
- Create: `test/klass_hero_web/live/dashboard_live/family_programs_test.exs`

**Step 1: Write tests**

```elixir
defmodule KlassHeroWeb.DashboardLive.FamilyProgramsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Family Programs section" do
    test "shows empty state when parent has no enrollments", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#family-programs")
      assert has_element?(view, "#family-programs-empty")
      assert has_element?(view, "a[href='/programs']")
    end
  end
end
```

**Step 2: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/dashboard_live/family_programs_test.exs -v`
Expected: PASS (empty state should render for new users with no enrollments)

**Step 3: Commit**

```bash
git add test/klass_hero_web/live/dashboard_live/family_programs_test.exs
git commit -m "test: add Family Programs section tests (#154)"
```

---

### Task 7: Run full precommit and verify

**Step 1: Run precommit**

Run: `mix precommit`
Expected: All checks pass (compile, format, tests)

**Step 2: Fix any issues found**

Address warnings, format issues, or test failures.

**Step 3: Final commit if needed**

```bash
git add -A && git commit -m "chore: fix precommit issues (#154)"
```
