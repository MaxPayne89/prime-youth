# Provider Profiles Admin Dashboard — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Backpex LiveResource for provider profiles in the admin dashboard with search, filtering, and scoped edit (verified + subscription_tier only).

**Architecture:** Backpex LiveResource operating directly on `ProviderProfileSchema` (same pragmatic exception as `UserLive`). New `admin_changeset/3` on the schema restricts editable fields. Route added to existing `:backpex_admin` live_session.

**Tech Stack:** Elixir, Phoenix LiveView, Backpex 0.17, Ecto

**Skills:** @idiomatic-elixir, @elixir-ecto-patterns

---

### Task 1: Add admin_changeset to ProviderProfileSchema

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs`

**Step 1: Write the failing test**

Create test file:

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema

  describe "admin_changeset/3" do
    setup do
      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      {:ok, schema} =
        %ProviderProfileSchema{}
        |> ProviderProfileSchema.changeset(%{
          identity_id: user.id,
          business_name: "Test Business"
        })
        |> KlassHero.Repo.insert()

      %{schema: schema}
    end

    test "casts verified and subscription_tier", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(schema, %{
          verified: true,
          subscription_tier: "professional"
        }, %{})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :verified) == true
      assert Ecto.Changeset.get_change(changeset, :subscription_tier) == "professional"
    end

    test "ignores provider-owned fields", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(schema, %{
          business_name: "Hacked Name",
          description: "Hacked Desc",
          phone: "555-HACK",
          website: "https://hacked.com",
          address: "Hacked Address"
        }, %{})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :business_name) == nil
      assert Ecto.Changeset.get_change(changeset, :description) == nil
      assert Ecto.Changeset.get_change(changeset, :phone) == nil
      assert Ecto.Changeset.get_change(changeset, :website) == nil
      assert Ecto.Changeset.get_change(changeset, :address) == nil
    end

    test "validates subscription_tier inclusion", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(schema, %{
          subscription_tier: "invalid_tier"
        }, %{})

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:subscription_tier]
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs -v`
Expected: Compilation error — `admin_changeset/3` is undefined.

**Step 3: Write minimal implementation**

Add to `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex` after `edit_changeset/2`:

```elixir
@doc """
Admin changeset for provider profile management via Backpex.

Only casts `verified` and `subscription_tier` — provider-owned fields
(business_name, description, phone, etc.) are excluded.

Accepts 3 args to match the Backpex changeset callback signature.
"""
def admin_changeset(schema, attrs, _metadata) do
  schema
  |> cast(attrs, [:verified, :subscription_tier])
  |> validate_inclusion(:subscription_tier, ["starter", "professional", "business_plus"])
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs -v`
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex \
        test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs
git commit -m "feat: add admin_changeset to ProviderProfileSchema

Scoped changeset for Backpex admin edits — only casts verified
and subscription_tier. Provider-owned fields are excluded."
```

---

### Task 2: Create ProviderLive Backpex LiveResource

**Files:**
- Create: `lib/klass_hero_web/live/admin/provider_live.ex`
- Test: `test/klass_hero_web/live/admin/provider_live_test.exs`

**Step 1: Write the failing tests**

```elixir
defmodule KlassHeroWeb.Admin.ProviderLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import KlassHero.ProviderFixtures

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/providers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/providers")
      assert html =~ "Providers"
    end

    test "new provider button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/providers")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/providers", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/providers")
      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/providers", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/providers")
    end
  end

  describe "provider list" do
    setup :register_and_log_in_admin

    test "displays providers in the table", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Acme Activities")

      {:ok, view, _html} = live(conn, ~p"/admin/providers")

      assert has_element?(view, "td", "Acme Activities")
    end
  end

  describe "edit provider" do
    setup :register_and_log_in_admin

    test "admin can toggle verified status", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Verify Me")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{verified: true}})
      |> render_submit(%{"save-type" => "save"})

      schema = KlassHero.Repo.get!(
        KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
        provider.id
      )
      assert schema.verified == true
    end

    test "admin can change subscription tier", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Tier Change")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{subscription_tier: "professional"}})
      |> render_submit(%{"save-type" => "save"})

      schema = KlassHero.Repo.get!(
        KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
        provider.id
      )
      assert schema.subscription_tier == "professional"
    end

    test "rejects invalid subscription tier", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Bad Tier")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{subscription_tier: "invalid"}})
      |> render_submit(%{"save-type" => "save"})

      schema = KlassHero.Repo.get!(
        KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
        provider.id
      )
      assert schema.subscription_tier == "starter"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/provider_live_test.exs -v`
Expected: Compilation error or route not found.

**Step 3: Create the LiveResource**

Create `lib/klass_hero_web/live/admin/provider_live.ex`:

```elixir
defmodule KlassHeroWeb.Admin.ProviderLive do
  @moduledoc """
  Backpex LiveResource for managing provider profiles in the admin dashboard.

  Provides index, show, and edit views. Only verified status and
  subscription tier are editable — all other fields are provider-owned.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema.admin_changeset/3,
      # Required by Backpex even though :new is disabled via can?/3
      create_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  # Trigger: :new and :delete are not valid operations for provider profiles
  # Why: providers create their own profiles; deletion follows GDPR process
  # Outcome: hides "New" button, denies create/delete actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :delete, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true
  def can?(_assigns, :edit, _item), do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def singular_name, do: "Provider"

  @impl Backpex.LiveResource
  def plural_name, do: "Providers"

  @impl Backpex.LiveResource
  def fields do
    [
      business_name: %{
        module: Backpex.Fields.Text,
        label: "Business Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      verified: %{
        module: Backpex.Fields.Boolean,
        label: "Verified",
        orderable: true
      },
      subscription_tier: %{
        module: Backpex.Fields.Select,
        label: "Tier",
        orderable: true,
        options: [
          {"Starter", "starter"},
          {"Professional", "professional"},
          {"Business Plus", "business_plus"}
        ]
      },
      description: %{
        module: Backpex.Fields.Textarea,
        label: "Description",
        only: [:show],
        readonly: true
      },
      phone: %{
        module: Backpex.Fields.Text,
        label: "Phone",
        only: [:show],
        readonly: true
      },
      website: %{
        module: Backpex.Fields.URL,
        label: "Website",
        only: [:show],
        readonly: true
      },
      address: %{
        module: Backpex.Fields.Text,
        label: "Address",
        only: [:show],
        readonly: true
      },
      categories: %{
        module: Backpex.Fields.Text,
        label: "Categories",
        only: [:show],
        readonly: true,
        render: fn assigns ->
          import Phoenix.Component, only: [sigil_H: 2]

          categories = Map.get(assigns, :value, []) || []
          display = Enum.join(categories, ", ")

          ~H"""
          {display}
          """
        end
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        only: [:index, :show],
        orderable: true
      }
    ]
  end
end
```

**Step 4: Add route to router**

In `lib/klass_hero_web/router.ex`, inside the `:backpex_admin` live_session (line 149), add after the users line:

```elixir
live_resources("/providers", ProviderLive, only: [:index, :show, :edit])
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/admin/provider_live_test.exs -v`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add lib/klass_hero_web/live/admin/provider_live.ex \
        test/klass_hero_web/live/admin/provider_live_test.exs \
        lib/klass_hero_web/router.ex
git commit -m "feat: add provider profiles Backpex admin resource

Backpex LiveResource with search by business name, sort by
verified/tier/date. Edit scoped to verified + subscription_tier.
Closes #338"
```

---

### Task 3: Add sidebar navigation link

**Files:**
- Modify: `lib/klass_hero_web/components/layouts/admin.html.heex`

**Step 1: Add the sidebar item**

After the Users sidebar item (line 29), add:

```heex
<Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/providers"}>
  <Backpex.HTML.CoreComponents.icon name="hero-building-storefront" class="h-5 w-5" /> {gettext("Providers")}
</Backpex.HTML.Layout.sidebar_item>
```

**Step 2: Verify manually**

Run: `mix phx.server` and navigate to `/admin/providers`. Confirm sidebar shows both "Users" and "Providers" links.

**Step 3: Commit**

```bash
git add lib/klass_hero_web/components/layouts/admin.html.heex
git commit -m "feat: add providers link to admin sidebar"
```

---

### Task 4: Run full test suite + precommit

**Step 1: Run precommit checks**

Run: `mix precommit`
Expected: Compilation (0 warnings), format (no changes), all tests pass.

**Step 2: Fix any issues**

If warnings or test failures, fix them before proceeding.

**Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve precommit issues"
```

---

### Notes

- **Backpex field modules reference:** Check available field types with `mix usage_rules.docs Backpex.Fields.Text` if unsure about a field module (e.g., `Backpex.Fields.URL` vs `Backpex.Fields.Text`).
- **categories field:** The `render` option may need adjustment based on Backpex 0.17 API. If `render` isn't supported, fall back to `Backpex.Fields.Text` with readonly and let it display the raw list.
- **Boundary config:** `ProviderProfileSchema` is already inside the Provider context. Backpex accesses it directly via Repo — this matches the UserLive precedent and is an accepted architectural exception.
