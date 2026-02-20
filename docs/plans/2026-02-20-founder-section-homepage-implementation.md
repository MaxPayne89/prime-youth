# Founder Section Homepage Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Built by Parents to Empower Educators" founder section to the homepage between the provider section and FAQ.

**Architecture:** Single inline section in `home_live.ex` template. Simple centered text block with section label, heading, body paragraph, and CTA link to `/about`. No new components needed.

**Tech Stack:** Phoenix LiveView, HEEx, Theme module, Gettext

**Design doc:** `docs/plans/2026-02-20-founder-section-homepage-design.md`

---

### Task 1: Write test for founder section

**Files:**
- Modify: `test/klass_hero_web/live/home_live_test.exs:176` (insert before FAQ test)

**Step 1: Add test**

Insert this test between the pricing tests (line 175) and the FAQ test (line 177):

```elixir
test "renders founder section", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/")

  assert has_element?(view, "#founder-section")
  assert has_element?(view, "h2", "Built by Parents to Empower Educators.")
  assert has_element?(view, "#founder-section a[href='/about']", "Read our founding story")
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/home_live_test.exs --only line:177`

Expected: FAIL — `#founder-section` not found.

---

### Task 2: Add founder section to homepage template

**Files:**
- Modify: `lib/klass_hero_web/live/home_live.ex:451` (insert between hidden pricing comment end and FAQ section)

**Step 1: Add founder section HTML**

Insert between line 451 (the `-%>` closing the hidden pricing comment) and line 452 (the FAQ section comment). The new section goes here:

```heex
    <!-- Founder Section - trust signal for parents (#179) -->
      <div id="founder-section" class={[Theme.bg(:surface), "py-16 lg:py-24"]}>
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div class="mb-12">
            <.section_label>{gettext("Our Story")}</.section_label>
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Built by Parents to Empower Educators.")}
            </h2>
            <p class={["text-lg leading-relaxed", Theme.text_color(:secondary)]}>
              {gettext(
                "As fathers and partners of teachers in Berlin, we saw and heard firsthand how hard it is to find, book, and manage quality youth activities outside the classroom. Klass Hero is the complete platform connecting Berlin families and schools with trusted, vetted activity providers — offering safe, supervised, and enriching experiences across sports, arts, tutoring, and more. We verify every provider, structure every booking, and support every step — so parents know their child is in good hands, and providers can focus on what they do best: inspiring kids."
              )}
            </p>
          </div>
          <.link
            navigate={~p"/about"}
            class={[
              Theme.gradient(:primary),
              "inline-block px-8 py-3 text-white hover:shadow-lg transform hover:scale-105",
              Theme.typography(:cta),
              Theme.transition(:normal),
              Theme.rounded(:lg)
            ]}
          >
            {gettext("Read our founding story →")}
          </.link>
        </div>
      </div>
```

**Step 2: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/home_live_test.exs`

Expected: ALL PASS.

**Step 3: Commit**

```bash
git add lib/klass_hero_web/live/home_live.ex test/klass_hero_web/live/home_live_test.exs
git commit -m "feat: add founder section to homepage (#179)"
```

---

### Task 3: Run full precommit checks

**Step 1: Run precommit**

Run: `mix precommit`

Expected: All checks pass (compile with warnings-as-errors, format, tests).

**Step 2: Fix any issues**

If warnings or test failures, fix and re-run until clean.

---

### Task 4: Visual verification

**Step 1: Check the section in browser**

Navigate to `http://localhost:4000` and verify:
- Founder section appears between provider section and FAQ
- "Our Story" label renders
- Heading and body text display correctly
- "Read our founding story" CTA links to `/about`
- Mobile responsive (text reflows, spacing looks good)

**Step 2: Close issue**

If all looks good, the feature is complete. Close beads issue if one exists.
