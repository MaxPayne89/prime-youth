# Founding Story Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Founding Team card grid with a narrative founding story and add a mission line to the Berlin Families section.

**Architecture:** Pure template change in `AboutLive`. No new modules, no DB, no routes. Update existing tests to match new content.

**Tech Stack:** Phoenix LiveView, HEEx, Gettext

---

### Task 1: Update tests — replace Founding Team assertions with Founding Story assertions

**Files:**
- Modify: `test/klass_hero_web/live/about_live_test.exs:82-116`

**Step 1: Replace the "Founding Team" test (line 82-88) with Founding Story test**

Replace:
```elixir
    test "displays Founding Team section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading
      assert html =~ "The Founding Team"
      assert html =~ "Meet the team building the future"
    end
```

With:
```elixir
    test "displays The Klass Hero Story section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "The Klass Hero Story"
      assert html =~ "Built by Parents and Educators for More Learning Opportunities"
    end
```

**Step 2: Replace the "three founding team members" test (line 90-107) with story content test**

Replace:
```elixir
    test "displays all three founding team members", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Shane Ogilvie
      assert html =~ "Shane Ogilvie"
      assert html =~ "CEO &amp; Co-Founder"
      assert html =~ "Former education technology leader"

      # Max Pergl
      assert html =~ "Max Pergl"
      assert html =~ "CTO &amp; Co-Founder"
      assert html =~ "Technology innovator"

      # Konstantin Pergl
      assert html =~ "Konstantin Pergl"
      assert html =~ "CFO &amp; Co-Founder"
      assert html =~ "Financial strategist"
    end
```

With:
```elixir
    test "displays founding story paragraphs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Trigger: verify all four founding story paragraphs are present
      # Why: each paragraph covers a different founder's contribution
      assert html =~ "Shane spent over a decade as a coach"
      assert html =~ "Max Pergl, a full-stack developer"
      assert html =~ "Konstantin Pergl"
      assert html =~ "Laurie Camargo"
    end
```

**Step 3: Remove the "team member avatars" test (line 109-116)**

Delete entirely:
```elixir
    test "team member avatars have colored backgrounds", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify colored avatar backgrounds
      assert html =~ "bg-hero-blue-400"
      assert html =~ "bg-pink-500"
      assert html =~ "bg-orange-500"
    end
```

**Step 4: Update responsive design test (line 142-149) — remove `md:grid-cols-3` assertion**

The 3-column team grid is gone. Replace:
```elixir
    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify responsive grid classes
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
      assert html =~ "md:grid-cols-3"
    end
```

With:
```elixir
    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify responsive grid classes
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end
```

**Step 5: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/about_live_test.exs`
Expected: FAIL — new assertions don't match current template yet.

---

### Task 2: Add "We are Klass Hero" line to Berlin Families section

**Files:**
- Modify: `lib/klass_hero_web/live/about_live.ex:115-119`
- Modify: `test/klass_hero_web/live/about_live_test.exs:21-28`

**Step 1: Add test assertion for the new line**

In test "displays Built for Berlin Families section" (line 21-28), add assertion:

```elixir
    test "displays Built for Berlin Families section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading and content
      assert html =~ "Built for Berlin Families"
      assert html =~ "unique needs of Berlin&#39;s diverse families"
      assert html =~ "sports to arts, technology to languages"
      assert html =~ "We are Klass Hero"
    end
```

**Step 2: Add the paragraph in the template**

In `about_live.ex`, after line 119 (closing `</p>` of the second paragraph), add:

```heex
            <p class="text-lg text-hero-grey-700 leading-relaxed font-medium">
              {gettext(
                "We are Klass Hero — parents, brothers, and partners of educators — building the infrastructure that helps every child learn and thrive."
              )}
            </p>
```

**Step 3: Run tests**

Run: `mix test test/klass_hero_web/live/about_live_test.exs --only test:"displays Built for Berlin Families section"`
Expected: PASS

---

### Task 3: Replace Founding Team section with Founding Story

**Files:**
- Modify: `lib/klass_hero_web/live/about_live.ex:233-257`

**Step 1: Replace the Founding Team template block**

Replace lines 233-257 (the entire `<%!-- Founding Team Section --%>` block) with:

```heex
      <%!-- The Klass Hero Story Section --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24">
        <div class="text-center mb-12">
          <h2 class="font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4">
            {gettext("The Klass Hero Story")}
          </h2>
          <p class="text-lg text-hero-grey-700 max-w-3xl mx-auto">
            {gettext("Built by Parents and Educators for More Learning Opportunities")}
          </p>
        </div>

        <div class="max-w-3xl mx-auto space-y-6">
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Shane spent over a decade as a coach and youth activity provider in Berlin, building Prime Youth, a community of providers, schools, and parents dedicated to giving children the best possible experiences. But one pattern kept emerging: the administrative burden of managing bookings, payments, and compliance was getting in everyone's way. Shane saw the problem from every angle. That experience became the foundation for Klass Hero."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "In 2025, Shane connected with his friend Max Pergl, a full-stack developer who shared a unique perspective. Both Shane and Max are partners of teachers who wanted to extend their expertise beyond the classroom, offering more to the community, but without the time to manage bookings, payments, and compliance on their own."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Klass Hero was built to solve exactly that. A comprehensive operational platform that empowers educators to spend less time on paperwork and more time inspiring children."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "Konstantin Pergl, Max's brother, joined as CFO, bringing the financial rigour and strategic planning needed to navigate the German market and ensure long-term stability for every provider on the platform."
            )}
          </p>
          <p class="text-lg text-hero-grey-700 leading-relaxed">
            {gettext(
              "To lead trust and quality, Laurie Camargo, a mother with over a decade of experience in child safety and quality assurance, will join to architect our Safety-First Verification engine, ensuring every Hero meets the highest standards before working with families."
            )}
          </p>
        </div>
      </div>
```

**Step 2: Run the founding story tests**

Run: `mix test test/klass_hero_web/live/about_live_test.exs`
Expected: PASS for all story-related tests.

---

### Task 4: Remove unused `team_members/0` and commit

**Files:**
- Modify: `lib/klass_hero_web/live/about_live.ex:47-83`

**Step 1: Delete the `team_members/0` function**

Remove lines 47-83 entirely (the `defp team_members do ... end` block).

**Step 2: Compile with warnings-as-errors**

Run: `mix compile --warnings-as-errors`
Expected: PASS with no warnings (no remaining references to `team_members/0`).

**Step 3: Run full test suite**

Run: `mix test test/klass_hero_web/live/about_live_test.exs`
Expected: All tests PASS.

**Step 4: Run precommit**

Run: `mix precommit`
Expected: PASS (compile, format, test all green).

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/about_live.ex test/klass_hero_web/live/about_live_test.exs
git commit -m "feat: add founding story to About page (#180)"
```
