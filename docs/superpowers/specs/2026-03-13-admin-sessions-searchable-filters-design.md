# Admin Sessions: Searchable Filters

**Date:** 2026-03-13
**Status:** Approved
**Issue:** #344 (enhancement to existing admin sessions dashboard)

## Problem

The admin sessions filter form requires raw UUIDs for provider and program fields. No human admin can memorize UUIDs — the filters are unusable in practice.

## Decisions

1. **Separate searchable dropdowns** for provider and program (not a single unified search box)
2. **Merge today/filter modes** into one unified view — always show filters, date defaults to today
3. **Pure LiveView server-side filtering** with `phx-debounce="300"` — no custom JS hooks (uses `Phoenix.LiveView.JS` commands for click-away behavior)
4. **Provider cascades to program** — selecting a provider narrows program options to that provider's programs
5. **Reusable SearchableSelect LiveComponent** — encapsulates dropdown state, usable across admin views. LiveComponent is necessary here because each searchable dropdown requires independent mutable state (search term, open/closed, filtered options). A function component cannot hold per-instance state. This is the "strong, specific need" that justifies a LiveComponent per project conventions.
6. **Shared Admin.Queries module** — cross-context read-only queries for admin dropdowns, not tied to any domain context

## SearchableSelect LiveComponent

**Module:** `KlassHeroWeb.Admin.Components.SearchableSelect`

**Props (attrs):**
- `id` (required) — unique DOM id
- `label` — display label (e.g., "Provider")
- `options` — list of `%{id: uuid, label: "display name"}` maps
- `selected` — currently selected `%{id, label}` or `nil`
- `placeholder` — input placeholder text
- `field_name` — name for the hidden input (e.g., `"provider_id"`)

**Internal state:**
- `search_term` — current text in the input
- `open?` — whether the dropdown is visible
- `filtered_options` — options matching the search term

**Behavior:**
- Typing fires `phx-change` with `phx-debounce="300"`, server filters options via case-insensitive `String.contains?`
- Matching options rendered as a dropdown list below the input
- Clicking an option sends `send(self(), {:select, field_name, selected})` to the parent LiveView, e.g. `{:select, "provider_id", %{id: "uuid-here", label: "Creative Learning Inc."}}`. `field_name` is always a string matching the `field_name` prop.
- Parent handles `:select` message via `handle_info/2`, stores the selected ID, cascades if needed, re-queries sessions
- "x" button clears the selection
- `phx-click-away` closes the dropdown (via `Phoenix.LiveView.JS` — no custom JS hooks)
- Empty `options` list renders the dropdown with a "No results" message

## Unified Filter Bar

Replaces the today/filter mode toggle. Always visible at the top of the index view.

**Layout (mobile-first, wraps on small screens):**
1. **Provider** — `SearchableSelect`, placeholder "All providers"
2. **Program** — `SearchableSelect`, placeholder "All programs", options cascade from provider
3. **Date from / Date to** — two date inputs side by side. Both default to today (showing a single day). Admin can change either to create a range. A "clear" link resets both to today. If "from" is cleared but "to" remains (or vice versa), treat the missing bound as today. This preserves the existing date range capability while defaulting to the common "show me today" case.
4. **Status** — native `<select>` dropdown (unchanged from current)

**Filtering is live** — each selection immediately re-queries sessions. No "Apply" button.

**Session rows always show date** — no mode-based conditional.

## Data Loading

**On mount:** preload all providers and programs via `Admin.Queries`:
- `list_providers_for_select/0` → `[%{id: uuid, label: "Business Name"}, ...]`
- `list_programs_for_select/0` → `[%{id: uuid, label: "Program Title", provider_id: uuid}, ...]`

Program filtering by provider happens client-side in the LiveView (filter `@programs` by `provider_id`), not via an additional query.

**Session queries unchanged** — `Participation.list_admin_sessions/1` already accepts `provider_id` and `program_id` filters. The LiveView now passes UUIDs from dropdown selections instead of raw text input.

## Admin.Queries Module

**Module:** `KlassHero.Admin.Queries`

Located in `lib/klass_hero/admin/queries.ex` (not the web layer) since it executes Ecto/Repo queries directly — this is data access, not presentation.

Shared read-only queries for admin dropdown/select data. Cross-context by design — admin dashboards need to read across bounded contexts for display purposes.

Two functions initially:
- `list_providers_for_select/0` — `SELECT id, business_name FROM providers ORDER BY business_name`
- `list_programs_for_select/0` — `SELECT id, title, provider_id FROM programs ORDER BY title`

Returns plain maps, not domain structs. No domain logic.

**Scaling note:** With B-scale data (20-100 providers, 50-300 programs), preloading all options on mount is fine. Program filtering by selected provider happens in-memory in the LiveView. If data grows to C-scale (hundreds+), these functions would need to accept a search term parameter and return paginated results.

## File Changes

**New files:**
- `lib/klass_hero_web/live/admin/components/searchable_select.ex`
- `lib/klass_hero/admin/queries.ex`

**Modified files:**
- `lib/klass_hero_web/live/admin/sessions_live.ex` — remove mode logic, add filter state, preload data, handle `:select` messages
- `lib/klass_hero_web/live/admin/sessions_live.html.heex` — replace mode switcher and UUID form with unified filter bar

**No changes to:**
- Router
- Database schemas / migrations
- Participation context / repository
- Domain models or ports

## Testing

- **`SearchableSelect` component tests** — renders, filters on typing, selects, clears, handles empty options
- **`Admin.Queries` tests** — returns expected map shapes with correct keys
- **`SessionsLive` test updates:**
  - Remove: `"today mode"` and `"filter mode"` describe blocks and mode-switching tests
  - Update: index tests to verify unified filter bar renders with searchable dropdowns
  - Add: filter interaction tests (select provider, verify program cascade, select program, verify session list updates)
  - Keep unchanged: `:show` action tests (correction form, roster table)
