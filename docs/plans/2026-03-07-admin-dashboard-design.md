# Admin Dashboard Design — Backpex Integration

**Issue:** #308 — Create basic admin dashboard using @naymspace/backpex
**Date:** 2026-03-07
**Status:** Approved

## Overview

Integrate Backpex as the admin dashboard foundation, starting with User management. The dashboard lives in its own layout, separate from the main app and the existing verifications admin page.

## Decisions

- **Approach:** Backpex library (declarative LiveResource definitions)
- **Initial resource:** Users only (read + limited edit: `name`, `is_admin`)
- **Existing verifications page:** Stays as-is, not migrated to Backpex
- **Layout:** Standalone Backpex admin layout, separate from the app layout
- **No new migrations:** Backpex works with existing schemas

## 1. Dependencies & Setup

- Add `{:backpex, "~> 0.17"}` to `mix.exs`
- CSS: Add Backpex `@source` directives to `assets/css/app.css`
- JS: Import `BackpexHooks` and merge with existing hooks in `assets/js/app.js`
- Router: Add `plug Backpex.ThemeSelectorPlug` to `:backpex_admin` pipeline (scoped to admin routes only)

daisyUI and Tailwind CSS v4 are already in the project.

## 2. Admin Layout

**New files:**
- `lib/klass_hero_web/components/layouts/admin.html.heex`

**Changes:**
- `lib/klass_hero_web/components/layouts.ex` — add `admin/1` function

Uses Backpex layout components (`app_shell`, `topbar_branding`, `sidebar_item`, `flash_messages`).

Sidebar: "Users" link, "Back to App" link.
Topbar: Branding, current user email, log out.

## 3. Routing

New Backpex live_session under `/admin`, coexisting with the existing `:require_admin` session:

```elixir
import Backpex.Router

scope "/admin", KlassHeroWeb.Admin do
  pipe_through :browser

  backpex_routes()

  live_session :backpex_admin,
    layout: {KlassHeroWeb.Layouts, :admin},
    on_mount: [
      {KlassHeroWeb.UserAuth, :mount_current_scope},
      {KlassHeroWeb.UserAuth, :require_authenticated},
      {KlassHeroWeb.UserAuth, :require_admin},
      {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale},
      Backpex.InitAssigns
    ] do
    live_resources "/users", UserLive
  end
end
```

- Auth hooks run before `Backpex.InitAssigns`
- `backpex_routes()` outside the live_session
- Route restricted to `:index`, `:show`, `:edit` (no create/delete)
- Add "Admin Dashboard" link in `app.html.heex` admin dropdown

## 4. User LiveResource

**New file:** `lib/klass_hero_web/live/admin/user_live.ex`

| Field | Type | Index | Show | Edit | Searchable | Orderable |
|-------|------|-------|------|------|------------|-----------|
| `email` | Text | yes | yes | no | yes | yes |
| `name` | Text | yes | yes | yes | yes | yes |
| `is_admin` | Boolean | yes | yes | yes | no | yes |
| `intended_roles` | Text (read-only) | yes | yes | no | no | no |
| `confirmed_at` | DateTime | yes | yes | no | no | yes |
| `inserted_at` | DateTime | yes | yes | no | no | yes |

Changeset wrapper in the module: only casts `name` and `is_admin`. Backpex requires `/3` arity `(item, attrs, metadata)`.

## 5. Testing

**File:** `test/klass_hero_web/live/admin/user_live_test.exs`

- Route access control: non-admin redirected, admin can access
- User list rendering: table shows expected columns
- Edit restrictions: only `name` and `is_admin` editable

Uses existing `AccountsFixtures` with `is_admin: true`.

## Files Changed

| File | Action |
|------|--------|
| `mix.exs` | Add backpex dep |
| `assets/css/app.css` | Add Backpex `@source` directives |
| `assets/js/app.js` | Import and merge BackpexHooks |
| `lib/klass_hero_web/router.ex` | Add Backpex routes, import, ThemeSelectorPlug |
| `lib/klass_hero_web/components/layouts.ex` | Add `admin/1` function |
| `lib/klass_hero_web/components/layouts/admin.html.heex` | New admin layout |
| `lib/klass_hero_web/live/admin/user_live.ex` | New Backpex LiveResource |
| `lib/klass_hero_web/components/layouts/app.html.heex` | Add dashboard link to admin dropdown |
| `test/klass_hero_web/live/admin/user_live_test.exs` | New tests |
