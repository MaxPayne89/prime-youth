# Admin Dashboard (Backpex) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Backpex as an admin dashboard with User management (read + limited edit).

**Architecture:** Backpex LiveResource for Users with a standalone admin layout, coexisting with the existing verifications admin page. Auth uses existing `require_admin` on_mount hook.

**Tech Stack:** Elixir/Phoenix, Backpex ~> 0.17, daisyUI (already installed), Tailwind CSS v4 (already installed)

**Design Doc:** `docs/plans/2026-03-07-admin-dashboard-design.md`

---

### Task 1: Add Backpex Dependency

**Files:**
- Modify: `mix.exs:52-111` (deps list)

**Step 1: Add the dependency**

In `mix.exs`, add to the `deps` function after the `{:boundary, ...}` line:

```elixir
# Admin dashboard
{:backpex, "~> 0.17"}
```

**Step 2: Fetch and compile**

Run: `mix deps.get && mix deps.compile backpex`
Expected: Dependencies resolve, backpex compiles without errors.

**Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "deps: add backpex for admin dashboard"
```

---

### Task 2: Integrate Backpex CSS and JS

**Files:**
- Modify: `assets/css/app.css:1-7` (add @source directives)
- Modify: `assets/js/app.js:1-41` (import and merge BackpexHooks)

**Step 1: Add Backpex source directives to CSS**

In `assets/css/app.css`, after the existing `@source "../../lib/klass_hero_web";` line (line 7), add:

```css
@source "../../deps/backpex/**/*.*ex";
@source "../../deps/backpex/assets/js/**/*.*js";
```

**Step 2: Import and merge Backpex JS hooks**

In `assets/js/app.js`, add after the existing hook imports (after line 29):

```javascript
import { Hooks as BackpexHooks } from "backpex";
```

Then update the hooks object in the LiveSocket constructor (line 35-40) to merge BackpexHooks:

```javascript
hooks: {
  ...colocatedHooks,
  ...BackpexHooks,
  Debounce: DebounceHook,
  ScrollToBottom: ScrollToBottomHook,
  AutoResizeTextarea: AutoResizeTextareaHook
},
```

**Step 3: Verify assets compile**

Run: `mix assets.build`
Expected: Tailwind and esbuild compile without errors.

**Step 4: Commit**

```bash
git add assets/css/app.css assets/js/app.js
git commit -m "feat: integrate Backpex CSS sources and JS hooks"
```

---

### Task 3: Add ThemeSelectorPlug and Router Setup

**Files:**
- Modify: `lib/klass_hero_web/router.ex:1-16` (add plug and import)

**Step 1: Add ThemeSelectorPlug to browser pipeline**

In `lib/klass_hero_web/router.ex`, add `plug Backpex.ThemeSelectorPlug` at the end of the `:browser` pipeline (after line 15):

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {KlassHeroWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :fetch_current_scope_for_user
  plug :set_error_tracker_context
  plug KlassHeroWeb.Plugs.SetLocale
  plug Backpex.ThemeSelectorPlug
end
```

**Step 2: Add Backpex.Router import**

At the top of the router module, after the existing `import KlassHeroWeb.UserAuth` (line 4), add:

```elixir
import Backpex.Router
```

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly.

**Step 4: Commit**

```bash
git add lib/klass_hero_web/router.ex
git commit -m "feat: add Backpex router import and ThemeSelectorPlug"
```

---

### Task 4: Create Admin Layout

**Files:**
- Modify: `lib/klass_hero_web/components/layouts.ex:1-102` (add admin/1 function attrs)
- Create: `lib/klass_hero_web/components/layouts/admin.html.heex`

**Docs to check:** `Backpex.HTML.Layout` — functions `app_shell/1`, `topbar/1`, `topbar_branding/1`, `topbar_dropdown/1`, `sidebar_item/1`, `flash_messages/1`.

**Step 1: Add admin function declaration to layouts.ex**

In `lib/klass_hero_web/components/layouts.ex`, before the closing `end` (line 102), add:

```elixir
attr :flash, :map, required: true
attr :fluid?, :boolean, default: true
attr :current_url, :string, required: true
slot :inner_block, required: true

def admin(assigns)
```

Note: `embed_templates "layouts/*"` on line 12 will automatically pick up `admin.html.heex`.

**Step 2: Create the admin layout template**

Create `lib/klass_hero_web/components/layouts/admin.html.heex` using Backpex layout components. The template should include:

- `Backpex.HTML.Layout.app_shell/1` as the outer wrapper
- Topbar with Klass Hero branding and user dropdown (email + log out link)
- Sidebar with "Users" item linking to `/admin/users` and "Back to App" linking to `/`
- Flash messages
- `{render_slot(@inner_block)}` for main content

Refer to Backpex documentation for exact component signatures. A minimal starting point:

```heex
<Backpex.HTML.Layout.app_shell fluid?={@fluid?}>
  <:topbar>
    <Backpex.HTML.Layout.topbar_branding label="Klass Hero Admin" url={~p"/admin/users"} />
    <Backpex.HTML.Layout.topbar_dropdown>
      <:label>
        {if assigns[:current_scope], do: @current_scope.user.email, else: "Admin"}
      </:label>
      <li>
        <.link navigate={~p"/"}>Back to App</.link>
      </li>
      <li>
        <.link href={~p"/users/log-out"} method="delete">Sign Out</.link>
      </li>
    </Backpex.HTML.Layout.topbar_dropdown>
  </:topbar>
  <:sidebar>
    <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/users"}>
      <.icon name="hero-users" /> Users
    </Backpex.HTML.Layout.sidebar_item>
  </:sidebar>
  <Backpex.HTML.Layout.flash_messages flash={@flash} />
  {render_slot(@inner_block)}
</Backpex.HTML.Layout.app_shell>
```

**Important:** The exact component API may differ from this sketch. Consult the Backpex docs (`mix usage_rules.docs Backpex.HTML.Layout`) when implementing. Adjust slots, attrs, and structure to match the actual API.

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly.

**Step 4: Commit**

```bash
git add lib/klass_hero_web/components/layouts.ex lib/klass_hero_web/components/layouts/admin.html.heex
git commit -m "feat: add standalone admin layout with Backpex shell"
```

---

### Task 5: Write Failing Tests for Admin User Access Control

**Files:**
- Create: `test/klass_hero_web/live/admin/user_live_test.exs`

**Test helpers available:**
- `setup :register_and_log_in_admin` — creates admin user, logs in, sets `%{conn, user, scope}` in context
- `setup :register_and_log_in_user` — creates regular (non-admin) user

**Step 1: Write the failing access control tests**

```elixir
defmodule KlassHeroWeb.Admin.UserLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "Users"
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/users")
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/user_live_test.exs`
Expected: FAIL — route `/admin/users` does not exist yet (no matching route / function clause error).

**Step 3: Commit failing tests**

```bash
git add test/klass_hero_web/live/admin/user_live_test.exs
git commit -m "test: add failing access control tests for admin user dashboard"
```

---

### Task 6: Add Backpex Routes and User LiveResource (Make Tests Pass)

**Files:**
- Modify: `lib/klass_hero_web/router.ex:109-122` (add Backpex live_session after existing admin routes)
- Create: `lib/klass_hero_web/live/admin/user_live.ex`

**Step 1: Add Backpex admin routes**

In `lib/klass_hero_web/router.ex`, after the existing `:require_admin` live_session block (after line 122), but still inside the `scope "/", KlassHeroWeb do` block (before line 123's `end`), add:

```elixir
# Backpex admin dashboard - separate live_session with Backpex layout
scope "/admin", Admin do
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
    live_resources "/users", UserLive, only: [:index, :show, :edit]
  end
end
```

**Note:** This scope is inside the outer `scope "/", KlassHeroWeb do` block, so the module alias resolves to `KlassHeroWeb.Admin.UserLive`.

**Step 2: Create the User LiveResource**

Create `lib/klass_hero_web/live/admin/user_live.ex`:

```elixir
defmodule KlassHeroWeb.Admin.UserLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Accounts.User,
      repo: KlassHero.Repo,
      update_changeset: &__MODULE__.update_changeset/3,
      create_changeset: &__MODULE__.update_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def fields do
    [
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        orderable: true,
        readonly: true
      },
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        orderable: true
      },
      is_admin: %{
        module: Backpex.Fields.Boolean,
        label: "Admin",
        orderable: true
      },
      intended_roles: %{
        module: Backpex.Fields.Text,
        label: "Roles",
        render: fn assigns ->
          roles = assigns.value || []
          assigns = Phoenix.Component.assign(assigns, :display, Enum.join(Enum.map(roles, &to_string/1), ", "))
          ~H"{@display}"
        end,
        only: [:index, :show]
      },
      confirmed_at: %{
        module: Backpex.Fields.DateTime,
        label: "Confirmed At",
        only: [:index, :show],
        orderable: true
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        only: [:index, :show],
        orderable: true
      }
    ]
  end

  @doc """
  Admin changeset for User — only allows editing name and is_admin.
  Backpex requires /3 arity: (item, attrs, metadata).
  """
  def update_changeset(user, attrs, _metadata) do
    user
    |> Ecto.Changeset.cast(attrs, [:name, :is_admin])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, min: 2, max: 100)
  end
end
```

**Important:** The exact Backpex field options (`readonly`, `render`, `only`) may differ from this sketch. Consult Backpex docs when implementing:
- `mix usage_rules.docs Backpex.LiveResource`
- `mix usage_rules.docs Backpex.Fields.Text`
- `mix usage_rules.docs Backpex.Fields.Boolean`
- `mix usage_rules.docs Backpex.Fields.DateTime`

Adjust the field configuration to match the actual API.

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly.

**Step 4: Run access control tests**

Run: `mix test test/klass_hero_web/live/admin/user_live_test.exs`
Expected: All 3 access control tests PASS.

**Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass, no regressions.

**Step 6: Commit**

```bash
git add lib/klass_hero_web/router.ex lib/klass_hero_web/live/admin/user_live.ex
git commit -m "feat: add Backpex admin routes and User LiveResource"
```

---

### Task 7: Write and Pass User List Rendering Tests

**Files:**
- Modify: `test/klass_hero_web/live/admin/user_live_test.exs`

**Step 1: Write failing user list tests**

Add to the existing test file, inside a new describe block:

```elixir
describe "user list" do
  setup :register_and_log_in_admin

  test "displays users in the table", %{conn: conn, user: admin} do
    # Create an additional regular user to verify listing
    regular_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Regular Test User"})

    {:ok, _view, html} = live(conn, ~p"/admin/users")

    assert html =~ admin.email
    assert html =~ admin.name
    assert html =~ regular_user.email
    assert html =~ regular_user.name
  end
end
```

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/admin/user_live_test.exs`
Expected: If LiveResource is wired correctly, these should PASS. If they fail, adjust the LiveResource field config until they pass.

**Step 3: Commit**

```bash
git add test/klass_hero_web/live/admin/user_live_test.exs
git commit -m "test: add user list rendering tests for admin dashboard"
```

---

### Task 8: Write and Pass Edit Restriction Tests

**Files:**
- Modify: `test/klass_hero_web/live/admin/user_live_test.exs`

**Step 1: Write failing edit tests**

Add a new describe block:

```elixir
describe "edit user" do
  setup :register_and_log_in_admin

  test "admin can update user name", %{conn: conn} do
    target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Original Name"})

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{target_user.id}/edit")

    # Submit name change via Backpex edit form
    # The exact form target/event depends on Backpex internals
    view
    |> form("#backpex-resource-form", %{change: %{name: "Updated Name"}})
    |> render_submit()

    updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
    assert updated.name == "Updated Name"
  end

  test "admin can toggle is_admin flag", %{conn: conn} do
    target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Toggle Target"})
    assert target_user.is_admin == false

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{target_user.id}/edit")

    view
    |> form("#backpex-resource-form", %{change: %{is_admin: true}})
    |> render_submit()

    updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
    assert updated.is_admin == true
  end
end
```

**Important:** Backpex form IDs and param structures may differ. When implementing:
1. First render the edit page and inspect the HTML to find the actual form ID and param names
2. Use `LazyHTML` to debug: `html |> LazyHTML.from_fragment() |> LazyHTML.filter("form") |> IO.inspect()`
3. Adjust test selectors to match actual Backpex output

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/admin/user_live_test.exs`
Expected: PASS — changeset only allows `name` and `is_admin`.

**Step 3: Run full test suite for regressions**

Run: `mix test`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add test/klass_hero_web/live/admin/user_live_test.exs
git commit -m "test: add edit restriction tests for admin user management"
```

---

### Task 9: Add Dashboard Link to App Navigation

**Files:**
- Modify: `lib/klass_hero_web/components/layouts/app.html.heex:155-171` (desktop admin dropdown)
- Modify: `lib/klass_hero_web/components/layouts/app.html.heex:265-274` (mobile admin section)

**Step 1: Add "Dashboard" link in desktop admin dropdown**

In `app.html.heex`, inside the admin section (after line 161, before the Verifications link), add:

```heex
<li>
  <.link
    navigate={~p"/admin/users"}
    class="text-hero-black-100 hover:bg-hero-grey-50"
  >
    <.icon name="hero-chart-bar-square" class="w-5 h-5" />
    {gettext("Dashboard")}
  </.link>
</li>
```

**Step 2: Add "Dashboard" link in mobile admin section**

In `app.html.heex`, inside the mobile admin section (after line 270, before the Verifications link), add:

```heex
<li>
  <.link navigate={~p"/admin/users"}>{gettext("Dashboard")}</.link>
</li>
```

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly.

**Step 4: Commit**

```bash
git add lib/klass_hero_web/components/layouts/app.html.heex
git commit -m "feat: add admin dashboard link to app navigation"
```

---

### Task 10: Final Verification and Precommit

**Step 1: Run precommit checks**

Run: `mix precommit`
Expected: All checks pass (compile --warnings-as-errors, format, test).

**Step 2: Manual smoke test**

Start the server: `mix phx.server`

Verify:
1. Navigate to `http://localhost:4000` — app works normally
2. Log in as admin user
3. Admin dropdown shows "Dashboard" and "Verifications" links
4. Click "Dashboard" — navigates to `/admin/users` with Backpex admin layout
5. User table shows list of users with Email, Name, Admin, Roles, Confirmed At, Created At columns
6. Click a user row — shows user detail
7. Click edit — only Name and Admin fields are editable
8. Edit a user's name — change persists
9. "Verifications" link still works from app navbar (separate from Backpex)
10. Non-admin user cannot access `/admin/users` (redirected with error flash)

**Step 3: Commit any final adjustments**

If smoke testing required fixes, commit them.

**Step 4: Push**

```bash
git push
```
