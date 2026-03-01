# Remove icon_path, Derive Icons from Category — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the unused/broken `icon_path` field and derive program icons from the category using heroicons.

**Architecture:** Add `icon_name/1` to `Shared.Categories` mapping each category to a heroicon name. Remove `icon_path` from domain model, schemas, mappers, projections, and UI. Replace all raw `<svg><path d=...>` with `<.icon name={...} />`. No DB migration — column stays, we just stop reading/writing it.

**Tech Stack:** Elixir/Phoenix, HEEx templates, Heroicons (Tailwind plugin)

---

### Task 1: Add `icon_name/1` to Shared.Categories

**Files:**
- Modify: `lib/klass_hero/shared/categories.ex:29-43`
- Test: `test/klass_hero/shared/categories_test.exs` (may need to create)

**Step 1: Write the failing test**

Create or update the categories test file:

```elixir
# test/klass_hero/shared/categories_test.exs
defmodule KlassHero.Shared.CategoriesTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Categories

  describe "icon_name/1" do
    test "returns heroicon name for each valid category" do
      assert Categories.icon_name("sports") == "hero-trophy"
      assert Categories.icon_name("arts") == "hero-paint-brush"
      assert Categories.icon_name("music") == "hero-musical-note"
      assert Categories.icon_name("education") == "hero-academic-cap"
      assert Categories.icon_name("life-skills") == "hero-light-bulb"
      assert Categories.icon_name("camps") == "hero-fire"
      assert Categories.icon_name("workshops") == "hero-wrench-screwdriver"
    end

    test "returns fallback for unknown category" do
      assert Categories.icon_name("unknown") == "hero-academic-cap"
    end

    test "returns fallback for nil" do
      assert Categories.icon_name(nil) == "hero-academic-cap"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/shared/categories_test.exs -v`
Expected: FAIL — `Categories.icon_name/1` is undefined

**Step 3: Implement `icon_name/1`**

Add to `lib/klass_hero/shared/categories.ex` after `valid_category?/1` (after line 43):

```elixir
@doc """
Returns the heroicon name for a given category.

Used by UI components to render category-appropriate icons.

## Examples

    iex> KlassHero.Shared.Categories.icon_name("sports")
    "hero-trophy"

    iex> KlassHero.Shared.Categories.icon_name(nil)
    "hero-academic-cap"
"""
@spec icon_name(String.t() | nil) :: String.t()
def icon_name("sports"), do: "hero-trophy"
def icon_name("arts"), do: "hero-paint-brush"
def icon_name("music"), do: "hero-musical-note"
def icon_name("education"), do: "hero-academic-cap"
def icon_name("life-skills"), do: "hero-light-bulb"
def icon_name("camps"), do: "hero-fire"
def icon_name("workshops"), do: "hero-wrench-screwdriver"
def icon_name(_), do: "hero-academic-cap"
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/shared/categories_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/shared/categories.ex test/klass_hero/shared/categories_test.exs
git commit -m "feat: add icon_name/1 mapping categories to heroicons"
```

---

### Task 2: Remove `icon_path` from Domain Model

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex:24,48,198,270`

**Step 1: Remove `:icon_path` from struct (line 24)**

Delete `:icon_path,` from the `defstruct` list.

**Step 2: Remove from typespec (line 48)**

Delete `icon_path: String.t() | nil,` from `@type t`.

**Step 3: Remove from `build_base/3` (line 198)**

Delete `icon_path: attrs[:icon_path],` from the struct construction.

**Step 4: Remove from `@updatable_fields` (line 270)**

Remove `icon_path` from the `~w(...)a` sigil. The line currently reads:
```
age_range pricing_period icon_path end_date location cover_image_url
```
Change to:
```
age_range pricing_period end_date location cover_image_url
```

**Step 5: Run tests**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs -v`
Expected: Some tests may need `icon_path` references removed. Fix any failures.

**Step 6: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex
git commit -m "refactor: remove icon_path from Program domain model"
```

---

### Task 3: Remove `icon_path` from ProgramListing Read Model

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/read_models/program_listing.ex:20,49`

**Step 1: Remove from typespec (line 20)**

Delete `icon_path: String.t() | nil,`

**Step 2: Remove from defstruct (line 49)**

Delete `:icon_path,`

**Step 3: Run tests**

Run: `mix test test/klass_hero/program_catalog/ -v`
Expected: Some tests may reference `icon_path` in ProgramListing — fix them.

**Step 4: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/read_models/program_listing.ex
git commit -m "refactor: remove icon_path from ProgramListing read model"
```

---

### Task 4: Remove `icon_path` from Ecto Schemas (stop reading/writing)

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex:30,59,100,203`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_listing_schema.ex:24`

**Step 1: ProgramSchema — remove field declaration (line 30)**

Delete `field :icon_path, :string`

**Step 2: ProgramSchema — remove from typespec (line 59)**

Delete `icon_path: String.t() | nil,`

**Step 3: ProgramSchema — remove from `changeset/2` cast list (line 100)**

Delete `:icon_path,` from the cast list.

**Step 4: ProgramSchema — remove from `update_changeset/2` cast list (line 203)**

Delete `:icon_path,` from the cast list.

**Step 5: ProgramListingSchema — remove field (line 24)**

Delete `field :icon_path, :string`

**Step 6: Run tests**

Run: `mix test test/klass_hero/program_catalog/adapters/ -v`
Expected: Fix any test references to `icon_path` in schema tests.

**Step 7: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/
git commit -m "refactor: remove icon_path from Ecto schemas"
```

---

### Task 5: Remove `icon_path` from Mapper, Projections, and Use Cases

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex:35,59,109,128`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/projections/program_listings.ex:57,281,315,349`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/update_program.ex:71`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository.ex:164`

**Step 1: ProgramMapper — remove from `to_domain/1` (line 59)**

Delete `icon_path: schema.icon_path,`

**Step 2: ProgramMapper — remove from `to_schema/1` (line 128)**

Delete `icon_path: program.icon_path,`

**Step 3: ProgramMapper — clean up doc examples (lines 35, 109)**

Remove `icon_path` references from the `@doc` examples.

**Step 4: ProgramListings projection — remove from `@shared_fields` (line 57)**

Delete `:icon_path,`

**Step 5: ProgramListings projection — remove from `upsert_listing_from_event` (line 281)**

Delete `icon_path: Map.get(payload, :icon_path),`

**Step 6: ProgramListings projection — remove from `@update_fields` (line 315)**

Delete `:icon_path,`

**Step 7: ProgramListings projection — remove from `update_listing_from_event` (line 349)**

Delete `icon_path: Map.get(payload, :icon_path),`

**Step 8: UpdateProgram — remove from event payload (line 71)**

Delete `icon_path: program.icon_path,`

**Step 9: ProgramListingsRepository — remove from DTO mapping (line 164)**

Delete `icon_path: schema.icon_path,`

**Step 10: Run tests**

Run: `mix test test/klass_hero/program_catalog/ -v`
Expected: Fix any remaining test references.

**Step 11: Commit**

```bash
git add lib/klass_hero/program_catalog/
git commit -m "refactor: remove icon_path from mapper, projections, and use cases"
```

---

### Task 6: Update Templates — Replace raw SVG with heroicons

**Files:**
- Modify: `lib/klass_hero_web/components/program_components.ex:290-301`
- Modify: `lib/klass_hero_web/components/ui_components.ex:517-518,542-544,566-567,638-647,775,796-809`
- Modify: `lib/klass_hero_web/live/programs_live.ex:107-141,340-343`
- Modify: `lib/klass_hero_web/live/home_live.ex:151-161,197-199`
- Modify: `lib/klass_hero_web/live/program_detail_live.ex:178-186`
- Modify: `lib/klass_hero_web/presenters/program_presenter.ex:96,107-119`

**Step 1: program_components.ex — program card header**

Replace the SVG block (lines 290-301) with heroicon. The program map needs `icon_name` instead of `icon_path`.

Replace:
```heex
<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@program.icon_path} />
</svg>
```
With:
```heex
<.icon name={@program.icon_name} class="w-8 h-8 text-white" />
```

**Step 2: ui_components.ex — `program_card_simple`**

Change attr from `attr :icon_path, :string, required: true` to `attr :icon_name, :string, required: true`.

Replace the SVG block (line 643-646) with:
```heex
<.icon name={@icon_name} class="w-10 h-10 text-white" />
```

**Step 3: ui_components.ex — `feature_card`**

The `feature_card` component already supports `icon` attr and has the `icon_path` as a fallback. Remove the `icon_path` attr entirely (line 518). Remove the `else` SVG branch (lines 540-544). The caller on `home_live.ex:197` that uses `icon_path=` should switch to `icon=`.

New component rendering logic (just the icon part):
```heex
<.icon name={@icon} class="w-8 h-8 text-white" />
```

Make `icon` required instead of optional.

**Step 4: ui_components.ex — `empty_state`**

Same pattern as `feature_card`. Remove `icon_path` attr (line 775). Remove the SVG fallback branch (lines 795-810). Make `icon` required. The docstring examples need updating.

The callers need updating:
- `programs_live.ex:343`: change `icon_path="M21 21l..."` to `icon="hero-magnifying-glass"`
- `ui_components.ex` doc examples (lines 747-751, 763-764): update

**Step 5: programs_live.ex — `program_to_map/2`**

Import `Categories` at top of module. Replace:
```elixir
icon_path: program.icon_path || default_icon_path()
```
With:
```elixir
icon_name: Categories.icon_name(program.category)
```

Delete `default_icon_path/0` function (lines 140-141).

**Step 6: home_live.ex — featured programs**

Import `Categories` at top of module. Change line 155:
```heex
icon_path={program.icon_path}
```
To:
```heex
icon_name={Categories.icon_name(program.category)}
```

Change the first `feature_card` (line 197-199):
```heex
icon_path="M9 12l2 2 4-4m5.618..."
```
To:
```heex
icon="hero-shield-check"
```

**Step 7: program_detail_live.ex — hero icon**

Import `Categories` at top of module. Replace the SVG block (lines 178-186):
```heex
<svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@program.icon_path} />
</svg>
```
With:
```heex
<.icon name={Categories.icon_name(@program.category)} class="w-10 h-10 text-white" />
```

**Step 8: program_presenter.ex — `to_card_view/1`**

Import `Categories` at top. Replace line 96:
```elixir
icon_path: program.icon_path || default_icon_path(),
```
With:
```elixir
icon_name: Categories.icon_name(program.category),
```

Delete `default_icon_path/0` function (lines 107-112) and its comment (lines 107-109).

**Step 9: Run compilation check**

Run: `mix compile --warnings-as-errors`
Expected: No warnings, clean compile.

**Step 10: Commit**

```bash
git add lib/klass_hero_web/ lib/klass_hero_web/presenters/
git commit -m "refactor: replace icon_path SVG rendering with heroicon components"
```

---

### Task 7: Update Factory and Tests

**Files:**
- Modify: `test/support/factory.ex:88,118,145,176,191,206`
- Modify: `test/klass_hero_web/presenters/program_presenter_test.exs:228,245`
- Modify: `test/klass_hero_web/live/programs_live_test.exs:775`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs:30`
- Modify: various other test files referencing `icon_path`

**Step 1: Factory — remove `icon_path` from all factories**

- `program_factory`: delete `icon_path: "/images/icons/default.svg",` (line 88)
- `program_schema_factory`: delete `icon_path: "/images/icons/default.svg",` (line 118)
- `program_listing_schema_factory`: delete `icon_path: "/images/icons/default.svg",` (line 145)
- `soccer_program_factory`: delete `icon_path: "/images/icons/soccer.svg"` (line 176)
- `dance_program_factory`: delete `icon_path: "/images/icons/dance.svg"` (line 191)
- `yoga_program_factory`: delete `icon_path: "/images/icons/yoga.svg"` (line 206)

**Step 2: Fix test references**

Remove or update any test assertions that reference `icon_path`:
- `program_presenter_test.exs:228` — remove `icon_path` from test data, update assertion on line 245 to check `icon_name` matches `Categories.icon_name(category)`
- `programs_live_test.exs:775` — remove `icon_path` from program listing data
- `provider/dashboard_live_test.exs:30` — remove `icon_path: program.icon_path,`
- Any other test files found via grep

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add test/
git commit -m "test: remove icon_path from factories and test assertions"
```

---

### Task 8: Final Verification — precommit

**Step 1: Run precommit**

Run: `mix precommit`
Expected: Compile (no warnings) + format + tests all pass

**Step 2: Fix any remaining issues**

If any warnings or test failures, fix them.

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: fix remaining icon_path references"
```
