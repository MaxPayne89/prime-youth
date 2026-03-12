# Admin Account Overview Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the limited admin "Users" view with a richer "Accounts" overview displaying user roles (Parent, Provider, Admin) and subscription tiers as badges.

**Architecture:** Evolve the existing `UserLive` Backpex resource into `AccountLive`. Add `has_one` associations on the User schema to preload parent/provider profiles. Custom Backpex field renderers display role and subscription badges using `@item`. TDD for all new rendering behavior.

**Tech Stack:** Elixir/Phoenix, Backpex LiveResource, Ecto, ExUnit

**Spec:** `docs/superpowers/specs/2026-03-12-admin-account-overview-design.md`

**Skills:** @superpowers:test-driven-development, @idiomatic-elixir

---

## File Structure

### Modified Files

| File | Change |
|------|--------|
| `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex` | Add `has_one :parent_profile` and `has_one :provider_profile` associations |
| `lib/klass_hero_web/live/admin/user_live.ex` | Rename → `account_live.ex`: new module name, fields, `item_query`, custom renders |
| `lib/klass_hero_web/router.ex` | Route `/admin/users` → `/admin/accounts`, `UserLive` → `AccountLive` |
| `lib/klass_hero_web/components/layouts/admin.html.heex` | Sidebar link + label update |
| `lib/klass_hero_web/components/layouts/app.html.heex` | Two admin entry-point links update |
| `test/klass_hero_web/live/admin/user_live_test.exs` | Rename → `account_live_test.exs`: update routes, remove name-edit tests, add role/subscription tests |

### No New Files

All changes modify existing files. The `user_live.ex` → `account_live.ex` rename is done via `git mv`.

---

## Chunk 1: Schema Associations and Rename Infrastructure

### Task 1: Add `has_one` associations to User schema

**Files:**
- Modify: `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`

- [ ] **Step 1: Add aliases for cross-context schemas**

In `user.ex`, after the existing aliases (`alias KlassHero.Accounts.Domain.Models.User, as: DomainUser` and `alias KlassHero.Accounts.Types.{UserRole, UserRoles}`), add:

```elixir
# Cross-context references for admin dashboard preloading (read-only)
alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
```

- [ ] **Step 2: Add `has_one` associations inside the schema block**

After `field :provider_subscription_tier, :string, virtual: true` (line 31), add:

```elixir
has_one :parent_profile, ParentProfileSchema, foreign_key: :identity_id
has_one :provider_profile, ProviderProfileSchema, foreign_key: :identity_id
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles with zero warnings.

- [ ] **Step 4: Verify existing tests still pass**

Run: `mix test test/klass_hero_web/live/admin/user_live_test.exs`
Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex
git commit -m "feat: add has_one associations for parent/provider profiles on User schema

Cross-context read-only associations for admin dashboard preloading.
Closes no issue — part of #367."
```

---

### Task 2: Rename UserLive → AccountLive (file, module, route, navigation)

**Files:**
- Rename: `lib/klass_hero_web/live/admin/user_live.ex` → `lib/klass_hero_web/live/admin/account_live.ex`
- Modify: `lib/klass_hero_web/router.ex`
- Modify: `lib/klass_hero_web/components/layouts/admin.html.heex`
- Modify: `lib/klass_hero_web/components/layouts/app.html.heex`
- Rename: `test/klass_hero_web/live/admin/user_live_test.exs` → `test/klass_hero_web/live/admin/account_live_test.exs`

- [ ] **Step 1: Rename the LiveResource file**

```bash
git mv lib/klass_hero_web/live/admin/user_live.ex lib/klass_hero_web/live/admin/account_live.ex
```

- [ ] **Step 2: Update module name and Backpex names in `account_live.ex`**

Change module definition:

```elixir
# Before
defmodule KlassHeroWeb.Admin.UserLive do

# After
defmodule KlassHeroWeb.Admin.AccountLive do
```

Update moduledoc first line:

```elixir
# Before
Backpex LiveResource for managing users in the admin dashboard.

# After
Backpex LiveResource for the admin account overview.
```

Update singular/plural names:

```elixir
# Before
def singular_name, do: "User"
def plural_name, do: "Users"

# After
def singular_name, do: "Account"
def plural_name, do: "Accounts"
```

Leave the fields unchanged for now — they'll be updated in later tasks.

- [ ] **Step 3: Update router**

In `lib/klass_hero_web/router.ex`, change:

```elixir
# Before
live_resources("/users", UserLive, only: [:index, :show, :edit])

# After
live_resources("/accounts", AccountLive, only: [:index, :show, :edit])
```

- [ ] **Step 4: Update admin sidebar navigation**

In `lib/klass_hero_web/components/layouts/admin.html.heex`, change:

```heex
<%!-- Before --%>
<Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/users"}>
  <Backpex.HTML.CoreComponents.icon name="hero-users" class="h-5 w-5" /> {gettext("Users")}
</Backpex.HTML.Layout.sidebar_item>

<%!-- After --%>
<Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/accounts"}>
  <Backpex.HTML.CoreComponents.icon name="hero-users" class="h-5 w-5" /> {gettext("Accounts")}
</Backpex.HTML.Layout.sidebar_item>
```

- [ ] **Step 5: Update app layout admin links**

In `lib/klass_hero_web/components/layouts/app.html.heex`, change both occurrences:

```heex
<%!-- Before (2 places) --%>
navigate={~p"/admin/users"}

<%!-- After (2 places) --%>
navigate={~p"/admin/accounts"}
```

- [ ] **Step 6: Rename test file**

```bash
git mv test/klass_hero_web/live/admin/user_live_test.exs test/klass_hero_web/live/admin/account_live_test.exs
```

- [ ] **Step 7: Update test module name and all routes**

In `account_live_test.exs`, change:

Module name:
```elixir
# Before
defmodule KlassHeroWeb.Admin.UserLiveTest do

# After
defmodule KlassHeroWeb.Admin.AccountLiveTest do
```

All route references (9 occurrences):
```elixir
# Before
~p"/admin/users"
~p"/admin/users/#{...}/edit"

# After
~p"/admin/accounts"
~p"/admin/accounts/#{...}/edit"
```

Update the first test assertion:
```elixir
# Before
assert html =~ "Users"

# After
assert html =~ "Accounts"
```

- [ ] **Step 8: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles with zero warnings.

- [ ] **Step 9: Verify all renamed tests pass**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: all 8 tests pass.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor: rename admin UserLive to AccountLive

Route changes from /admin/users to /admin/accounts.
Aligns with ubiquitous language — part of #367."
```

---

## Chunk 2: TDD — Roles Badges

### Task 3: Add `item_query` for preloading and the Roles field

This task follows TDD: write failing tests for roles badges first, then implement the `item_query` preloading and roles field together (since the render function depends on preloaded data).

**Files:**
- Modify: `lib/klass_hero_web/live/admin/account_live.ex`
- Modify: `test/klass_hero_web/live/admin/account_live_test.exs`

- [ ] **Step 1: Write failing tests for roles badges**

Add to `account_live_test.exs`, after the existing `describe` blocks:

```elixir
describe "roles badges" do
  setup :register_and_log_in_admin

  test "displays Parent badge for user with parent profile", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Parent User"})
    KlassHero.Factory.insert(:parent_profile_schema, identity_id: user.id)

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Parent")
  end

  test "displays Provider badge for user with provider profile", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Provider User"})

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Test Biz"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Provider")
  end

  test "displays Admin badge for admin user", %{conn: conn} do
    _admin_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Other Admin", is_admin: true})

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    # The logged-in admin also has Admin badge, but we check for the other admin
    assert has_element?(view, "span", "Admin")
  end

  test "displays multiple badges for dual-role user", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Dual Role"})
    KlassHero.Factory.insert(:parent_profile_schema, identity_id: user.id)

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Dual Biz"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Parent")
    assert has_element?(view, "span", "Provider")
  end

  test "displays User badge for user with no profile and not admin", %{conn: conn} do
    _bare_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Bare User"})

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "User")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: new roles tests FAIL (no "Parent"/"Provider"/"Admin"/"User" badges rendered yet). Existing tests still pass.

- [ ] **Step 3: Add `item_query` to adapter_config in `account_live.ex`**

Update the `use Backpex.LiveResource` block. **Important:** bump `credo:disable-for-lines:10` to `credo:disable-for-lines:11` since we're adding one line (`item_query`) to the block:

```elixir
# credo:disable-for-lines:11 Credo.Check.Design.AliasUsage
use Backpex.LiveResource,
  adapter_config: [
    schema: KlassHero.Accounts.User,
    repo: KlassHero.Repo,
    update_changeset: &KlassHero.Accounts.User.admin_update_changeset/3,
    create_changeset: &KlassHero.Accounts.User.admin_update_changeset/3,
    item_query: &__MODULE__.item_query/3
  ],
  layout: {KlassHeroWeb.Layouts, :admin},
  pubsub: [server: KlassHero.PubSub],
  init_order: %{by: :inserted_at, direction: :desc}
```

Add `import Ecto.Query` right after the `use` block (before the `@impl` callbacks), then add the `item_query` function below the `can?/3` clauses:

```elixir
# At the top of the module, after `use Backpex.LiveResource`:
import Ecto.Query

# Below the can?/3 clauses:
@doc false
def item_query(query, _live_action, _assigns) do
  from u in query, preload: [:parent_profile, :provider_profile]
end
```

- [ ] **Step 4: Add the Roles field to `fields/0`**

Replace the existing `is_admin` field definition with a new `roles` field. Keep `is_admin` but change it to edit-only (will be done in Task 5). For now, add `roles` after `name`:

```elixir
roles: %{
  module: Backpex.Fields.Text,
  label: "Roles",
  readonly: true,
  only: [:index, :show],
  render: fn assigns ->
    ~H"""
    <div class="flex flex-wrap gap-1">
      <%= if @item.parent_profile do %>
        <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700">
          Parent
        </span>
      <% end %>
      <%= if @item.provider_profile do %>
        <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700">
          Provider
        </span>
      <% end %>
      <%= if @item.is_admin do %>
        <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-red-100 text-red-700">
          Admin
        </span>
      <% end %>
      <%= if !@item.parent_profile && !@item.provider_profile && !@item.is_admin do %>
        <span class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700">
          User
        </span>
      <% end %>
    </div>
    """
  end
},
```

- [ ] **Step 5: Run tests to verify roles badges pass**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: ALL tests pass including new roles badge tests.

- [ ] **Step 6: Verify compilation is clean**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/admin/account_live.ex test/klass_hero_web/live/admin/account_live_test.exs
git commit -m "feat: add roles badges to admin account overview

Displays Parent, Provider, Admin badges based on profile existence
and is_admin flag. Preloads associations via item_query.
Part of #367."
```

---

## Chunk 3: TDD — Subscription Badges

### Task 4: Add the Subscription field with tier badges

**Files:**
- Modify: `lib/klass_hero_web/live/admin/account_live.ex`
- Modify: `test/klass_hero_web/live/admin/account_live_test.exs`

- [ ] **Step 1: Write failing tests for subscription badges**

Add to `account_live_test.exs`:

```elixir
describe "subscription badges" do
  setup :register_and_log_in_admin

  test "displays Explorer badge for parent with explorer tier", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Explorer Parent"})

    KlassHero.Factory.insert(:parent_profile_schema,
      identity_id: user.id,
      subscription_tier: "explorer"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Explorer")
  end

  test "displays Active badge for parent with active tier", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Active Parent"})

    KlassHero.Factory.insert(:parent_profile_schema,
      identity_id: user.id,
      subscription_tier: "active"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Active")
  end

  test "displays Starter badge for provider with starter tier", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Starter Provider"})

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Starter Biz",
      subscription_tier: "starter"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Starter")
  end

  test "displays Professional badge for provider with professional tier", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Pro Provider"})

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Pro Biz",
      subscription_tier: "professional"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Professional")
  end

  test "displays Business+ badge for provider with business_plus tier", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Biz Plus Provider"})

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Biz Plus",
      subscription_tier: "business_plus"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Business+")
  end

  test "displays both tiers for dual-role user", %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{name: "Dual Tier"})

    KlassHero.Factory.insert(:parent_profile_schema,
      identity_id: user.id,
      subscription_tier: "active"
    )

    KlassHero.Factory.insert(:provider_profile_schema,
      identity_id: user.id,
      business_name: "Dual Tier Biz",
      subscription_tier: "professional"
    )

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    assert has_element?(view, "span", "Active")
    assert has_element?(view, "span", "Professional")
  end

  test "displays dash for user with no profiles", %{conn: conn} do
    _bare = KlassHero.AccountsFixtures.user_fixture(%{name: "No Sub User"})

    {:ok, view, _html} = live(conn, ~p"/admin/accounts")

    # The em-dash is rendered for users without any profiles
    assert render(view) =~ "—"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: subscription badge tests FAIL. Existing tests (including roles badges) still pass.

- [ ] **Step 3: Add the Subscription field to `fields/0` in `account_live.ex`**

Add after the `roles` field:

```elixir
subscription: %{
  module: Backpex.Fields.Text,
  label: "Subscription",
  readonly: true,
  only: [:index, :show],
  render: fn assigns ->
    ~H"""
    <div class="flex flex-wrap gap-1">
      <%= if @item.parent_profile do %>
        <span class={[
          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
          parent_tier_class(@item.parent_profile.subscription_tier)
        ]}>
          {parent_tier_label(@item.parent_profile.subscription_tier)}
        </span>
      <% end %>
      <%= if @item.provider_profile do %>
        <span class={[
          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
          provider_tier_class(@item.provider_profile.subscription_tier)
        ]}>
          {provider_tier_label(@item.provider_profile.subscription_tier)}
        </span>
      <% end %>
      <%= if !@item.parent_profile && !@item.provider_profile do %>
        <span>&mdash;</span>
      <% end %>
    </div>
    """
  end
},
```

Add helper functions at the bottom of the module (before the closing `end`):

```elixir
# Parent tier display helpers

defp parent_tier_label("explorer"), do: "Explorer"
defp parent_tier_label("active"), do: "Active"
defp parent_tier_label(tier), do: String.capitalize(tier || "")

defp parent_tier_class("explorer"), do: "bg-gray-100 text-gray-700"
defp parent_tier_class("active"), do: "bg-green-100 text-green-700"
defp parent_tier_class(_), do: "bg-gray-100 text-gray-700"

# Provider tier display helpers

defp provider_tier_label("starter"), do: "Starter"
defp provider_tier_label("professional"), do: "Professional"
defp provider_tier_label("business_plus"), do: "Business+"
defp provider_tier_label(tier), do: String.capitalize(tier || "")

defp provider_tier_class("starter"), do: "bg-gray-100 text-gray-700"
defp provider_tier_class("professional"), do: "bg-blue-100 text-blue-700"
defp provider_tier_class("business_plus"), do: "bg-amber-100 text-amber-700"
defp provider_tier_class(_), do: "bg-gray-100 text-gray-700"
```

- [ ] **Step 4: Run tests to verify subscription badges pass**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: ALL tests pass.

- [ ] **Step 5: Verify compilation is clean**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/admin/account_live.ex test/klass_hero_web/live/admin/account_live_test.exs
git commit -m "feat: add subscription tier badges to admin account overview

Displays parent tiers (Explorer, Active) and provider tiers
(Starter, Professional, Business+) using colored badges.
Part of #367."
```

---

## Chunk 4: Field Cleanup and Final Polish

### Task 5: Remove name editability, move admin to edit-only, clean up fields

**Files:**
- Modify: `lib/klass_hero_web/live/admin/account_live.ex`
- Modify: `test/klass_hero_web/live/admin/account_live_test.exs`

- [ ] **Step 1: Remove name-edit tests from `account_live_test.exs`**

Delete the entire `describe "edit user"` block (the one containing tests for "admin can update user name", "rejects blank name", "rejects name shorter than 2 characters"). Keep "admin can toggle is_admin flag" — move it into a new describe block:

```elixir
describe "admin toggle" do
  setup :register_and_log_in_admin

  test "admin can toggle is_admin flag", %{conn: conn} do
    target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Toggle Target"})
    assert target_user.is_admin == false

    {:ok, view, _html} = live(conn, ~p"/admin/accounts/#{target_user.id}/edit")

    view
    |> form("#resource-form", %{change: %{is_admin: true}})
    |> render_submit(%{"save-type" => "save"})

    updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
    assert updated.is_admin == true
  end
end
```

- [ ] **Step 2: Run tests to verify removed tests don't break anything**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: all remaining tests pass. Test count reduced by 3 (removed name-edit tests).

- [ ] **Step 3: Update fields in `account_live.ex`**

Make `name` readonly and move `is_admin` to edit-only. The final `fields/0` should be:

```elixir
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
      orderable: true,
      readonly: true
    },
    roles: %{
      # ... (already added in Task 3)
    },
    subscription: %{
      # ... (already added in Task 4)
    },
    is_admin: %{
      module: Backpex.Fields.Boolean,
      label: "Admin",
      only: [:edit]
    },
    inserted_at: %{
      module: Backpex.Fields.DateTime,
      label: "Created At",
      only: [:index, :show],
      orderable: true
    }
  ]
end
```

Key changes from original:
- `name`: added `readonly: true`
- `is_admin`: changed to `only: [:edit]`, removed `orderable: true` (not shown on index)
- `roles` and `subscription` fields already in place from Tasks 3–4

- [ ] **Step 4: Run all tests**

Run: `mix test test/klass_hero_web/live/admin/account_live_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Verify compilation is clean**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings.

- [ ] **Step 6: Run full pre-commit checks**

Run: `mix precommit`
Expected: compile, format, and full test suite pass.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/admin/account_live.ex test/klass_hero_web/live/admin/account_live_test.exs
git commit -m "feat: finalize admin account overview field layout

Name is now readonly, admin toggle is edit-only (absorbed into
roles badges on index). Removes name-edit tests.
Closes #367."
```
