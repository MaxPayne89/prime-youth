# Trust & Safety Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a public Trust & Safety page communicating Klass Hero's provider verification process and child safety commitment.

**Architecture:** Single LiveView module (`TrustSafetyLive`) with direct HEEx template (like About page), data helper for verification steps grid. Route in `:public` live_session. Nav links in desktop navbar, mobile sidebar, and footer.

**Tech Stack:** Elixir/Phoenix LiveView, Tailwind CSS, Theme module, UIComponents, Gettext

**Design doc:** `docs/plans/2026-03-06-trust-and-safety-page-design.md`

---

### Task 1: Skeleton LiveView + Route + Failing Test

**Files:**
- Create: `test/klass_hero_web/live/trust_safety_live_test.exs`
- Create: `lib/klass_hero_web/live/trust_safety_live.ex`
- Modify: `lib/klass_hero_web/router.ex:45` (add route after terms line)

**Step 1: Write the failing test**

```elixir
# test/klass_hero_web/live/trust_safety_live_test.exs
defmodule KlassHeroWeb.TrustSafetyLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "TrustSafetyLive" do
    test "renders trust and safety page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trust-safety")

      assert has_element?(view, "h1", "TRUST & SAFETY")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/trust_safety_live_test.exs`
Expected: FAIL — no route matches "/trust-safety"

**Step 3: Create skeleton LiveView + route**

```elixir
# lib/klass_hero_web/live/trust_safety_live.ex
defmodule KlassHeroWeb.TrustSafetyLive do
  use KlassHeroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Trust & Safety"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <h1>TRUST & SAFETY</h1>
    </div>
    """
  end
end
```

Add route in `lib/klass_hero_web/router.ex` after line 45 (`live "/terms", TermsOfServiceLive, :index`):

```elixir
      live "/trust-safety", TrustSafetyLive, :index
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/trust_safety_live_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/trust_safety_live.ex lib/klass_hero_web/router.ex test/klass_hero_web/live/trust_safety_live_test.exs
git commit -m "feat: add skeleton Trust & Safety page with route and test (#250)"
```

---

### Task 2: Full Page Content

**Files:**
- Modify: `lib/klass_hero_web/live/trust_safety_live.ex` (replace skeleton with full implementation)

**Reference patterns:**
- About page (`lib/klass_hero_web/live/about_live.ex`) — layout structure, `vetting_steps/0` data helper, Theme/UIComponents usage
- Theme module (`lib/klass_hero_web/components/theme.ex`) — `Theme.bg/1`, `Theme.gradient/1`, `Theme.text_color/1`
- Reference React component content from issue #250

**Step 1: Implement the full page**

Replace the entire `trust_safety_live.ex` with the full implementation:

- `alias KlassHeroWeb.{Theme, UIComponents}`
- `verification_steps/0` private function returning list of 6 maps, each with: `icon`, `icon_gradient`, `title`, `description` — all text wrapped in `gettext()`
- Icons: `hero-identification`, `hero-academic-cap`, `hero-shield-check`, `hero-video-camera`, `hero-heart`, `hero-check-circle`
- All icon gradients: `"bg-hero-blue-400"` (matching About page pattern)

Template sections (top to bottom):

1. **Hero** — `bg-hero-pink-50 py-16 lg:py-24`, centered layout:
   - `UIComponents.gradient_icon` with shield icon (`hero-shield-check`, gradient `bg-hero-blue-400`, size `"lg"`, shape `"circle"`)
   - `<h1>` with `font-display text-4xl md:text-5xl lg:text-6xl text-hero-black mb-6` containing `gettext("TRUST & SAFETY")`
   - Subtitle `<p>` with `text-xl text-hero-grey-600 max-w-3xl mx-auto`

2. **Commitment section** — `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24`, two-column `grid md:grid-cols-2 gap-8 md:gap-12 items-center`:
   - Left column: heading, description paragraph, 4 commitment items each in `border-2 border-hero-yellow-400 rounded-lg p-4 bg-white` cards with `hero-check-circle` icons
   - Right column: `bg-hero-blue-600 rounded-2xl p-8 text-white` card with "Vetted with Care" heading, description, shield icon watermark

3. **Verification section** — `bg-hero-pink-50 py-12 md:py-16 lg:py-24`:
   - Centered heading "How We Verify Providers"
   - `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8` iterating `verification_steps()`
   - Each step card: `bg-white rounded-xl p-6 text-center` with `UIComponents.gradient_icon`, title, description

4. **Accountability section** — `max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-24`:
   - `bg-gray-900 rounded-2xl p-8 md:p-10 text-white` card
   - `text-hero-yellow-400` heading "Ongoing Quality & Accountability"
   - Description paragraph in `text-gray-300`
   - 4 numbered items, each with `w-6 h-6 rounded-full bg-hero-yellow-400 text-hero-black font-bold text-xs` number badge
   - Italic warning in `text-gray-400 italic border-l-4 border-hero-yellow-400 pl-4`

5. **CTA section** — `bg-hero-pink-50 py-16 text-center`:
   - "Have Questions?" heading
   - Description paragraph
   - `.link navigate={~p"/contact"}` styled as primary button (`bg-hero-blue-600 hover:bg-hero-blue-700 text-white px-8 py-4 rounded-lg`)
   - Divider line
   - Closing tagline: "Trust is earned. Safety is non-negotiable."
   - Subline: "And at Klass Hero, both come standard."

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/trust_safety_live_test.exs`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/klass_hero_web/live/trust_safety_live.ex
git commit -m "feat: implement Trust & Safety page content (#250)"
```

---

### Task 3: Navigation Links

**Files:**
- Modify: `lib/klass_hero_web/components/layouts/app.html.heex:66-67` (desktop nav, after Contact `</li>`)
- Modify: `lib/klass_hero_web/components/layouts/app.html.heex:232` (mobile sidebar, after Contact `</li>`)
- Modify: `lib/klass_hero_web/components/composite_components.ex:657` (footer, after Terms of Service link)

**Step 1: Add desktop navbar link**

After line 67 (`</li>` closing Contact) in `app.html.heex`, add:

```heex
          <li>
            <.link
              navigate={~p"/trust-safety"}
              class="btn btn-ghost text-hero-black-100 hover:text-hero-blue-600"
            >
              {gettext("Trust & Safety")}
            </.link>
          </li>
```

**Step 2: Add mobile sidebar link**

After line 232 (`<li><.link navigate={~p"/contact"}>...`) in `app.html.heex`, add:

```heex
          <li><.link navigate={~p"/trust-safety"}>{gettext("Trust & Safety")}</.link></li>
```

**Step 3: Add footer link**

After line 657 (`<.link navigate={~p"/terms"} ...>`) in `composite_components.ex`, add:

```heex
          <span class="text-gray-400">&bull;</span>
          <.link navigate={~p"/trust-safety"} class="link link-hover">{gettext("Trust & Safety")}</.link>
```

**Step 4: Run tests**

Run: `mix test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero_web/components/layouts/app.html.heex lib/klass_hero_web/components/composite_components.ex
git commit -m "feat: add Trust & Safety links to navbar, sidebar, and footer (#250)"
```

---

### Task 4: Content Tests + Precommit

**Files:**
- Modify: `test/klass_hero_web/live/trust_safety_live_test.exs` (add content tests)

**Step 1: Add content tests**

Follow the pattern from `test/klass_hero_web/live/about_live_test.exs`. Add these tests to the existing describe block:

```elixir
    test "displays hero section with shield icon", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "TRUST &amp; SAFETY"
      assert html =~ "bg-hero-pink-50"
      assert html =~ "hero-shield-check"
    end

    test "displays commitment to child safety section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Our Commitment to Child Safety"
      assert html =~ "Protect children and families"
      assert html =~ "Vetted with Care"
    end

    test "displays all six verification steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "How We Verify Providers"
      assert html =~ "Identity &amp; Age Verification"
      assert html =~ "Experience Validation"
      assert html =~ "Extended Background Checks"
      assert html =~ "Video Screening"
      assert html =~ "Child Safeguarding Training"
      assert html =~ "Community Standards Agreement"
    end

    test "displays ongoing quality section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Ongoing Quality"
      assert html =~ "bg-gray-900"
    end

    test "displays CTA with contact link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Have Questions?"
      assert html =~ ~s(href="/contact")
    end

    test "displays closing tagline", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Trust is earned. Safety is non-negotiable."
    end

    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end
```

**Step 2: Run the full test to verify content tests pass**

Run: `mix test test/klass_hero_web/live/trust_safety_live_test.exs`
Expected: All PASS

**Step 3: Run precommit**

Run: `mix precommit`
Expected: Compile (0 warnings), format, tests all pass

**Step 4: Commit**

```bash
git add test/klass_hero_web/live/trust_safety_live_test.exs
git commit -m "test: add content tests for Trust & Safety page (#250)"
```

---

### Task 5: Extract Gettext + Final Push

**Step 1: Extract gettext strings**

Run: `mix gettext.extract`
Expected: New entries added to `priv/gettext/default.pot`

**Step 2: Merge gettext to locale files**

Run: `mix gettext.merge priv/gettext`
Expected: New entries added to `en` and `de` PO files (German translations left as empty — to be filled later)

**Step 3: Final precommit**

Run: `mix precommit`
Expected: All pass

**Step 4: Commit and push**

```bash
git add priv/gettext/
git commit -m "chore: extract gettext strings for Trust & Safety page (#250)"
git push
```
