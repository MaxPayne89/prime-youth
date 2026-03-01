# Remove icon_path, derive icons from category

**Date:** 2026-03-01
**Status:** Approved

## Problem

`icon_path` field stores raw SVG `d`-attribute strings, but:
- DB column is nil for all programs in production
- Test fixtures use file path strings (e.g. `/images/icons/art.svg`) instead of SVG d-strings
- Some render sites (`home_live.ex`, `program_detail_live.ex`) pass nil directly to `<path d={...}>`, causing browser console errors
- The field is semantically confused and unused

## Solution

Remove `icon_path` entirely. Derive icons from the program's `category` field using the existing `.icon` component (heroicons via Tailwind CSS plugin).

## Category-to-Icon Mapping

Add `icon_name/1` to `KlassHero.Shared.Categories`:

| Category | Heroicon |
|---|---|
| `"sports"` | `"hero-trophy"` |
| `"arts"` | `"hero-paint-brush"` |
| `"music"` | `"hero-musical-note"` |
| `"education"` | `"hero-academic-cap"` |
| `"life-skills"` | `"hero-light-bulb"` |
| `"camps"` | `"hero-fire"` |
| `"workshops"` | `"hero-wrench-screwdriver"` |
| fallback | `"hero-academic-cap"` |

## Template Changes

Replace all `<svg><path d={@icon_path}>` with `<.icon name={icon_name} class="..." />`.

Affected files:
- `program_components.ex` — program card header
- `ui_components.ex` — `program_card_simple`, `feature_card`, `empty_state`
- `programs_live.ex` — `program_to_map/2`
- `home_live.ex` — featured programs
- `program_detail_live.ex` — program detail header
- `program_presenter.ex` — `to_card_view/1`

## Domain Model Cleanup

Remove `:icon_path` from:
- `Program` struct, typespec, `@updatable_fields`, `build_base/3`
- `ProgramListing` read model
- Ecto schemas (stop reading/writing; keep DB column — no migration)
- `UpdateProgram` use case
- `ProgramMapper`
- Factory and test fixtures

## What NOT to do

- No DB migration to drop the column (harmless, avoids rollback risk)
- No changes to category list itself
