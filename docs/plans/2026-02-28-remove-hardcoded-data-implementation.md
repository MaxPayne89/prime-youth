# Remove Hardcoded Data — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all hardcoded/fake data from LiveViews before go-live. Wire up existing backends, comment out unsupported features, centralize contact info in config.

**Architecture:** Bottom-up deletion — delete fixture modules first, then fix every compile error. Each task is one logical unit with its own commit.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto, Gettext

**Design doc:** `docs/plans/2026-02-28-remove-hardcoded-data-design.md`

---

### Task 1: Add contact config and helper

**Files:**
- Modify: `config/config.exs`
- Create: `lib/klass_hero/contact.ex`

**Step 1: Add contact config to `config/config.exs`**

Add after the existing config blocks (before the `import_config` at end of file):

```elixir
# Contact information — centralized, configurable per environment
config :klass_hero, :contact,
  email: "info@klasshero.com",
  phone: nil,
  address: nil
```

**Step 2: Create a tiny helper module `lib/klass_hero/contact.ex`**

```elixir
defmodule KlassHero.Contact do
  @moduledoc """
  Centralized access to contact information from application config.
  """

  def email, do: get(:email)
  def phone, do: get(:phone)
  def address, do: get(:address)

  defp get(key) do
    :klass_hero
    |> Application.get_env(:contact, [])
    |> Keyword.get(key)
  end
end
```

**Step 3: Run `mix compile --warnings-as-errors`**

Expected: compiles cleanly.

**Step 4: Commit**

```
feat: add centralized contact info config and helper
```

---

### Task 2: Delete `sample_fixtures.ex` and fix `program_detail_live.ex`

This is the biggest task — `sample_fixtures.ex` is only imported by `program_detail_live.ex`.

**Files:**
- Delete: `lib/klass_hero_web/live/sample_fixtures.ex`
- Modify: `lib/klass_hero_web/live/program_detail_live.ex`

**Step 1: Delete `sample_fixtures.ex`**

Remove the file entirely.

**Step 2: Fix `program_detail_live.ex` — remove import and hardcoded assigns**

At line 4, remove:
```elixir
import KlassHeroWeb.Live.SampleFixtures
```

In `mount/3` (lines 32-38), remove the `included_items` injection:
```elixir
# Remove this entire block:
program_with_items = Map.put(program, :included_items, [
  gettext("Weekly art supplies and materials"),
  gettext("Take-home projects every week"),
  gettext("Portfolio folder to track progress"),
  gettext("Final exhibition showcase")
])
```

Update the variable name downstream — wherever `program_with_items` is used, use `program` directly.

At lines 53-54, remove the fake assigns:
```elixir
# Remove these two lines:
|> assign(instructor: sample_instructor())
|> assign(reviews: sample_reviews())
```

**Step 3: Wire up real data — location**

In the template at line 234, replace hardcoded "Berlin":
```heex
<%!-- Before: --%>
<.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> Berlin

<%!-- After: --%>
<.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> {@program.location}
```

If `@program.location` might be nil, wrap conditionally:
```heex
<span :if={@program.location} class="flex items-center">
  <.icon name="hero-map-pin" class="w-4 h-4 mr-1" /> {@program.location}
</span>
```

**Step 4: Wire up real data — date range in pricing card**

At line 290, replace hardcoded `"Total: Sept 1 - Oct 26"`:
```heex
<%!-- Before: --%>
{gettext("Total: Sept 1 - Oct 26")}

<%!-- After: --%>
<%= if date_range = ProgramPresenter.format_date_range_brief(@program) do %>
  {gettext("Total: %{range}", range: date_range)}
<% end %>
```

Add alias at top of module if not present:
```elixir
alias KlassHeroWeb.Presenters.ProgramPresenter
```

**Step 5: Comment out included_items section in template**

At lines 359-364, comment out the `included_items` `<ul>`:
```heex
<%!-- Commented out: included_items field not yet on Program schema
<ul class={["space-y-2 text-sm", Theme.text_color(:secondary)]}>
  <li :for={item <- @program.included_items} class="flex items-start">
    ...
  </li>
</ul>
--%>
```

Also check if there's a heading like "What's Included" above it that should also be commented out.

**Step 6: Comment out instructor fallback section in template**

At lines 452-476, the `<% else %>` branch that renders `@instructor` — comment out the entire else branch. Keep the `@team_members` branch (real data). If `@team_members` is empty, the section simply won't render.

Restructure the conditional: instead of if/else (real team vs fake instructor), use `:if` guard:
```heex
<%!-- Only show instructor section when real team members exist --%>
<section :if={@team_members != []}>
  <%!-- ... existing team_members rendering ... --%>
</section>
```

**Step 7: Comment out reviews section in template**

At lines 481-518, comment out the entire `<section>` for reviews:
```heex
<%!-- Commented out: reviews/ratings context not yet implemented
<section>
  ...
</section>
--%>
```

**Step 8: Run `mix compile --warnings-as-errors`**

Fix any remaining references to removed assigns (`@instructor`, `@reviews`, `@program.included_items`). There may be warnings about unused imports or variables.

**Step 9: Run `mix test`**

Fix any test failures. No tests currently reference SampleFixtures, but program_detail_live tests may break if they assert on commented-out sections.

**Step 10: Commit**

```
chore: remove sample_fixtures.ex and clean up program_detail_live
```

---

### Task 3: Delete `mock_data.ex` and fix provider dashboard

**Files:**
- Delete: `lib/klass_hero_web/live/provider/mock_data.ex`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`

**Step 1: Delete `mock_data.ex`**

Remove the file entirely.

**Step 2: Fix `provider/dashboard_live.ex`**

Remove the alias at line 22:
```elixir
alias KlassHeroWeb.Provider.MockData
```

At line 60, remove:
```elixir
stats = MockData.stats()
```

Remove the `assign(stats: stats)` at line 79.

**Step 3: Comment out stats in template**

The `<.overview_section>` at line 991 receives `stats={@stats}`. Either:
- Remove the `stats` attr from the component call, OR
- Comment out the stats cards inside `overview_section` (lines 1169-1206)

Simplest: assign a nil stats and guard the template:
```elixir
# In mount, remove stats assign entirely
# In template, wrap with :if
```

Or comment out the `<.overview_section>` call and the component definition.

**Step 4: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 5: Commit**

```
chore: remove provider mock_data.ex and comment out stats section
```

---

### Task 4: Clean up `programs_live.ex` — remove inline mock data

**Files:**
- Modify: `lib/klass_hero_web/live/programs_live.ex`

**Step 1: Remove `enrich_with_mock_data/1` and `enrich_program_with_mock_data/1`**

Delete the functions at lines 146-241. These inject fake provider names, ratings, review counts, and locations matched by program title.

**Step 2: Remove call site**

At line 131, `enrich_program_with_mock_data(base_map)` is called during program list building. Remove this call. The `base_map` should be used directly without enrichment.

**Step 3: Remove `@env` module attribute**

If `@env = Mix.env()` (used only for the mock data guard) is no longer needed, remove it.

**Step 4: Handle template references to removed fields**

The template likely references `program.provider_name`, `program.rating`, `program.review_count`, `program.provider_location`, etc. from the mock data. These fields won't exist on real programs.

For each removed field in the template:
- `provider_name` / `provider_avatar` / `provider_location` → conditionally render from `program.provider` association if preloaded, or hide
- `rating` / `review_count` → comment out (no reviews context)
- `is_verified` / `is_online` / `popularity_score` → comment out (no backend)

**Step 5: Wire up category filters**

At `filter_options/0` (lines 17-28), the current list is already consistent with `ProgramCatalog.valid_categories/0`. But to avoid drift, wire it up:

```elixir
defp filter_options do
  categories = ProgramCatalog.program_categories()

  [%{id: "all", label: gettext("All"), icon: "hero-squares-2x2"} |
   Enum.map(categories, fn cat ->
     %{id: cat, label: category_label(cat), icon: category_icon(cat)}
   end)]
end
```

Or, if the current implementation already matches and uses the same categories, this can be left as-is (it's UI config, not fake data). Use judgment — if the filter list exactly mirrors the valid categories, the existing static list is fine.

**Step 6: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 7: Commit**

```
chore: remove mock provider data from programs_live
```

---

### Task 5: Clean up `dashboard_live.ex` — remove hardcoded data

**Files:**
- Modify: `lib/klass_hero_web/live/dashboard_live.ex`

**Step 1: Remove hardcoded helper functions**

Delete these private functions:
- `get_achievements/1` (lines 70-77) — hardcoded achievements
- `get_recommended_programs/1` (lines 79-121) — hardcoded program recommendations

**Step 2: Simplify `get_referral_stats/1`**

Keep referral code generation (real), remove hardcoded count/points:
```elixir
defp get_referral_stats(user) do
  %{
    code: generate_referral_code(user)
  }
end
```

**Step 3: Remove assigns in `mount/3`**

At lines 49-51, remove:
```elixir
|> assign(achievements: get_achievements(socket))
|> assign(recommended_programs: get_recommended_programs(socket))
```

Update referral_stats assign to use simplified version.

**Step 4: Comment out template sections**

- Lines 298-301: Comment out achievements section (`<.family_achievements>`)
- Lines 348-389: Comment out recommended programs section
- Lines 390-393: Update referral card — either comment out or update to only show referral code (no count/points)

**Step 5: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 6: Commit**

```
chore: remove hardcoded achievements, recommendations, referral stats from dashboard
```

---

### Task 6: Clean up `booking_live.ex` — wire up real program data

**Files:**
- Modify: `lib/klass_hero_web/live/booking_live.ex`

**Step 1: Replace hardcoded fee module attributes with program-derived values**

Remove module attributes:
```elixir
@default_weekly_fee 45.00
@default_weeks_count 8
@default_registration_fee 25.00
@default_vat_rate 0.19
@default_card_processing_fee 2.50
```

In `mount/3`, derive fees from the program:
```elixir
# Use program.price as the weekly fee
# Program.price is a Decimal — convert to float for FeeCalculator
weekly_fee = program.price |> Decimal.to_float()

# Calculate weeks from program date range
weeks_count = calculate_weeks(program.start_date, program.end_date)
```

For `registration_fee`, `vat_rate`, `card_processing_fee` — these are business constants, not program-specific. Move to application config:

```elixir
# In config/config.exs:
config :klass_hero, :booking,
  registration_fee: 25.00,
  vat_rate: 0.19,
  card_processing_fee: 2.50
```

In `mount/3`:
```elixir
booking_config = Application.get_env(:klass_hero, :booking)

socket
|> assign(weekly_fee: weekly_fee)
|> assign(weeks_count: weeks_count)
|> assign(registration_fee: booking_config[:registration_fee])
|> assign(vat_rate: booking_config[:vat_rate])
|> assign(card_fee: booking_config[:card_processing_fee])
```

Add a helper:
```elixir
defp calculate_weeks(nil, _), do: 1
defp calculate_weeks(_, nil), do: 1
defp calculate_weeks(start_date, end_date) do
  Date.diff(end_date, start_date) |> div(7) |> max(1)
end
```

**Step 2: Wire up schedule and date range in template**

At line 364, replace `gettext("Wednesdays 4-6 PM")`:
```heex
<p class={["text-sm", Theme.text_color(:secondary)]}>
  {ProgramPresenter.format_schedule_brief(@program)}
</p>
```

At line 379, replace `gettext("Jan 15 - Mar 15, 2024")`:
```heex
<span class={Theme.text_color(:secondary)}>
  {ProgramPresenter.format_date_range_brief(@program)}
</span>
```

Add alias if not present:
```elixir
alias KlassHeroWeb.Presenters.ProgramPresenter
```

**Step 3: Comment out bank transfer details**

At lines 540-576, comment out the bank transfer info box:
```heex
<%!-- Commented out: bank transfer details pending payment config
<.info_box :if={@payment_method == "transfer"}>
  ...
</.info_box>
--%>
```

**Step 4: Fix hardcoded VAT label**

At line 523-525, the template shows `"VAT (19%)"` — make it dynamic:
```heex
{gettext("VAT (%{rate}%)", rate: trunc(@vat_rate * 100))}
```

**Step 5: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 6: Commit**

```
chore: wire booking fees to program data and config, remove hardcoded dates
```

---

### Task 7: Clean up `contact_live.ex` — use app config

**Files:**
- Modify: `lib/klass_hero_web/live/contact_live.ex`

**Step 1: Replace hardcoded contact info with config**

In `contact_methods/0` (lines 55-79), replace fake values:
```elixir
defp contact_methods do
  contact = Application.get_env(:klass_hero, :contact, [])

  [
    contact[:email] && %{
      icon: "hero-envelope",
      label: gettext("Email Us"),
      value: contact[:email],
      link: "mailto:#{contact[:email]}"
    },
    contact[:phone] && %{
      icon: "hero-phone",
      label: gettext("Call Us"),
      value: contact[:phone],
      link: "tel:#{contact[:phone]}"
    },
    contact[:address] && %{
      icon: "hero-map-pin",
      label: gettext("Visit Us"),
      value: contact[:address]
    }
  ]
  |> Enum.reject(&is_nil/1)
end
```

This way, only configured methods appear. With `phone: nil` and `address: nil` in config, only email shows.

**Step 2: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 3: Commit**

```
chore: wire contact_live to centralized contact config
```

---

### Task 8: Clean up footer in `composite_components.ex`

**Files:**
- Modify: `lib/klass_hero_web/components/composite_components.ex`

**Step 1: Replace hardcoded contact info in footer**

At lines 643-645, replace:
```heex
<%!-- Before: --%>
<p>Email: info@primeyouth.com</p>
<p>Phone: (555) 123-4567</p>

<%!-- After: --%>
<p :if={KlassHero.Contact.email()}>Email: {KlassHero.Contact.email()}</p>
<p :if={KlassHero.Contact.phone()}>Phone: {KlassHero.Contact.phone()}</p>
```

**Step 2: Fix hardcoded year**

At line 651, replace `&copy; 2025` with dynamic year:
```heex
&copy; {Date.utc_today().year} Klass Hero.
```

**Step 3: Run `mix compile --warnings-as-errors` and `mix test`**

**Step 4: Commit**

```
chore: wire footer contact info to config, dynamic copyright year
```

---

### Task 9: Final verification

**Step 1: Run full pre-commit checks**

```bash
mix precommit
```

This runs compile (warnings-as-errors), format, and tests.

**Step 2: Grep for remaining hardcoded data patterns**

```bash
# Search for fake emails
grep -r "primeyouth.com\|example.com" lib/
# Search for fake phone numbers
grep -r "(555)" lib/
# Search for fake addresses
grep -r "Learning Lane\|Youth Avenue" lib/
# Search for Unsplash URLs
grep -r "unsplash.com" lib/
# Search for remaining sample/mock references
grep -r "sample_\|mock_\|Mock\|Sample" lib/ --include="*.ex" --include="*.heex"
```

**Step 3: Fix any stragglers found**

**Step 4: Final commit if needed**

```
chore: final hardcoded data cleanup
```
