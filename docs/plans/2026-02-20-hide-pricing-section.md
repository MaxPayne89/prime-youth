# Hide Pricing Section Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Hide the homepage pricing section until transactions are live (#178).

**Architecture:** Comment out the HEEx pricing markup, skip related tests. Leave Elixir code (assign, event handler, component) untouched for easy re-enablement.

**Tech Stack:** Phoenix LiveView, HEEx templates, ExUnit

---

### Task 1: Comment Out Pricing Section in Template

**Files:**
- Modify: `lib/klass_hero_web/live/home_live.ex:297-444`

**Step 1: Wrap pricing section in HEEx comment**

In `home_live.ex`, replace lines 297-444 (the entire pricing section, from `<!-- Simple, Transparent Pricing Section -->` through the closing `</div>` before `<!-- Frequently Asked Questions Section -->`) with:

```heex
    <%!-- HIDDEN: Pricing section hidden until transactions are live (#178)
         Uncomment this block to re-enable pricing.

    <!-- Simple, Transparent Pricing Section -->
      <div id="pricing-section" ...>
        ... (existing pricing markup unchanged) ...
      </div>

    --%>
```

The comment starts BEFORE the `<!-- Simple, Transparent Pricing Section -->` comment on line 297 and ends AFTER the closing `</div>` on line 444, just before `<!-- Frequently Asked Questions Section -->` on line 446.

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with 0 warnings. May warn about unused `pricing_tab` assign — if so, that's acceptable since the assign/handler stay for re-enablement.

**Step 3: Commit**

```bash
git add lib/klass_hero_web/live/home_live.ex
git commit -m "refactor: hide pricing section on homepage (#178)"
```

---

### Task 2: Skip Pricing Tests

**Files:**
- Modify: `test/klass_hero_web/live/home_live_test.exs`

**Step 1: Add `@tag :skip` before each pricing test**

Add `@tag :skip` before each of these 7 tests:

- Line 132: `test "renders pricing section with family plans by default"`
- Line 143: `test "switches to provider pricing tab"`
- Line 156: `test "switches back to family pricing tab"`
- Line 209: `test "family pricing cards show all expected features"`
- Line 226: `test "provider pricing cards show all expected features"`
- Line 247: `test "pricing tab defaults to families on mount"`
- Line 258: `test "pricing tab assign updates when switching tabs"`

Example for each:

```elixir
@tag :skip
test "renders pricing section with family plans by default", %{conn: conn} do
```

**Step 2: Run full test suite**

Run: `mix test`
Expected: All tests pass. The 7 pricing tests show as skipped/excluded.

**Step 3: Commit**

```bash
git add test/klass_hero_web/live/home_live_test.exs
git commit -m "test: skip pricing section tests while hidden (#178)"
```

---

### Task 3: Run Precommit and Verify

**Step 1: Run precommit checks**

Run: `mix precommit`
Expected: Compilation (0 warnings), formatting, and all tests pass.

**Step 2: Visual verification (optional)**

Navigate to `http://localhost:4000/` and confirm pricing section is gone, FAQ section still renders correctly below the provider CTA.
