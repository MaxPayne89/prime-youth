# For Providers Info Page

## Context

Issue #25 ("Add 'For Providers' Info Page") requests a dedicated marketing page for potential providers (educators, coaches, artists) under the SEO & AEO OPTIMIZATION milestone. The user supplied a React design prototype with 6 sections to replicate in Phoenix LiveView/HEEx. The homepage also needs its provider CTA updated to link to this new page.

The Entitlements context already has `all_provider_tiers/0` returning real tier data (commission, seats, media). The provider domain is fully implemented. No new data infrastructure is needed.

---

## Milestone

**"For Providers Info Page"** — groups all 5 issues below under the existing SEO & AEO OPTIMIZATION milestone.

---

## Issues

### Issue 1 — Update Homepage Provider CTA
**Type:** feat | **Size:** XS (1 file, ~10 lines)

**Files:**
- `lib/klass_hero_web/live/home_live.ex` (lines ~259–329 — "For Providers" section)

**Changes:**
- Add "Are you an educator, coach, or artist?" subtitle above the button
- Change button text: `"Start Teaching Today →"` → `"Learn How to Become a Hero →"`
- Wire button to `~p"/for-providers"` via `<.link navigate={~p"/for-providers"}>`

---

### Issue 2 — Create /for-providers Route and Page Foundation
**Type:** feat | **Size:** S

**Files to create:**
- `lib/klass_hero_web/live/for_providers_live.ex`

**Files to modify:**
- `lib/klass_hero_web/router.ex` — add `live "/for-providers", ForProvidersLive, :index` inside the `:public` live_session block

**Module structure:**
```elixir
defmodule KlassHeroWeb.ForProvidersLive do
  use KlassHeroWeb, :live_view
  import KlassHeroWeb.UIComponents
  alias KlassHeroWeb.Theme

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("For Providers — Klass Hero"))}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- sections rendered inline -->
    </div>
    """
  end

  # Private helper functions for static data
  defp safety_steps(), do: [...]
  defp process_steps(), do: [...]
  defp support_items(), do: [...]
end
```

---

### Issue 3 — Hero Section and Value Propositions Section
**Type:** feat | **Size:** M

Implement the first two visual sections in `for_providers_live.ex`:

**Section 1 — Hero:**
- `bg-hero-pink-50 border-b border-hero-grey-200 py-20`
- `Theme.typography(:hero)` heading: `"Why Join Klass Hero?"`
- Highlight `"Klass Hero?"` in `text-hero-blue-600`
- Subheading text in `text-slate-700`
- CTA button using `Theme.gradient(:primary)` → `<.link navigate={~p"/users/register"}>`

**Section 2 — Value Propositions ("Empowering Educators"):**
- Two-column grid: left = 3 benefit items with `<.icon>` + title + desc; right = white card with image + blockquote
- Icon containers: `bg-hero-blue-50 text-hero-blue-600 p-3 rounded-lg`
- Benefits: "Reach a Ready-Made Community", "Get Paid Faster", "Focus on Teaching"
- Testimonial card: blockquote with `border-l-4 border-hero-blue-600` styling
- Background: `bg-hero-pink-50/30`

---

### Issue 4 — Safety Standards and Application Process Sections
**Type:** feat | **Size:** M

**Section 3 — Safety Standards ("Our Safety-First Standards"):**
- 8-card grid (4 columns on lg) using `<.feature_card>` or a custom `safety_step_card` inline component
- Use `hero-*` Heroicons: `shield-check`, `calendar-days`, `user-group`, `video-camera`, `heart`, `academic-cap`, `check-circle`, `shield-exclamation`
- Cards: `border-2 border-hero-grey-100 rounded-2xl p-6 hover:border-hero-blue-500`
- Background: white

**Data (helper function):**
```elixir
defp safety_steps() do
  [
    {:"shield-check", "Age Requirement", "Must be 18 years or older."},
    {:"academic-cap", "Experience", "Minimum of one year working with children."},
    {:"shield-exclamation", "Background Check", "Current, extended police background check."},
    {:"video-camera", "Video Screening", "Interactive screening of pedagogical approach."},
    {:"heart", "Child Safeguarding", "Mandatory safeguarding course completion."},
    {:"graduation-cap", "Qualifications", "Verification of degrees or certifications."},
    {:"check-circle", "Community Guidelines", "Formal agreement to Klass Hero standards."},
    {:"shield-check", "Insurance & Compliance", "Proof of liability insurance and health requirements."}
  ]
end
```

**Section 4 — Application Process:**
- 4-column grid with numbered steps using `<.provider_step_card>` (already exists in UIComponents)
- Background: `bg-hero-pink-200` (peach equivalent)
- Steps: Create Profile → Verification → List Programs → Go Live

---

### Issue 5 — Pricing Tiers, Support Section, Navigation Link, and Final CTA
**Type:** feat | **Size:** M

**Section 5 — Support & Pricing:**
- Two-column grid: left = support items (star ratings, analytics, growth support); right = pricing cards
- Use `KlassHero.Entitlements.all_provider_tiers/0` (or `provider_tier_info/1` per tier) for real pricing data — do not hardcode
- Mount: `assign(socket, tiers: KlassHero.Entitlements.all_provider_tiers())`
- Pricing card design: highlighted card for `:professional` tier using `border-hero-blue-600 bg-hero-blue-50`

**Section 6 — Final CTA:**
- Centered: "Ready to Inspire the Next Generation?"
- Primary button → `~p"/users/register"`

**Navigation:**
- `lib/klass_hero_web/components/layouts/app.html.heex`
- Add "For Providers" link after existing nav links in both desktop and mobile nav, pointing to `~p"/for-providers"`

---

## Verification

- `mix precommit` — zero warnings, all tests green
- Visit `http://localhost:4000/for-providers` — all 6 sections render correctly
- Verify pricing data comes from Entitlements (not hardcoded)
- Visit homepage — CTA button updated and links to `/for-providers`
- Desktop + mobile nav shows "For Providers" link
- Run `mix lint_typography` — no violations

---

## Critical Files

| File | Action |
|---|---|
| `lib/klass_hero_web/router.ex` | Add route |
| `lib/klass_hero_web/live/for_providers_live.ex` | Create new |
| `lib/klass_hero_web/live/home_live.ex` | Update CTA |
| `lib/klass_hero_web/components/layouts/app.html.heex` | Add nav link |
| `lib/klass_hero/entitlements.ex` | Read-only: `all_provider_tiers/0` |
| `lib/klass_hero_web/components/ui_components.ex` | Reuse: `feature_card`, `provider_step_card`, `icon` |
| `lib/klass_hero_web/components/theme.ex` | Reuse: `typography`, `gradient`, `bg`, `text_color` |
