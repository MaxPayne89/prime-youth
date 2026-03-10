# Admin Staff Members Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Staff Members (index/show/edit) to the admin dashboard with active-status toggle and provider filtering.

**Architecture:** Backpex LiveResource with admin_changeset/3 on existing StaffMemberSchema. BelongsTo association for provider display. Boolean filter for active status. No domain events.

**Tech Stack:** Elixir, Phoenix LiveView, Backpex, Ecto

**Spec:** `docs/superpowers/specs/2026-03-10-admin-staff-members-design.md`

**Skills:** @idiomatic-elixir (pattern matching, changesets at boundaries), @superpowers:test-driven-development (RED-GREEN-REFACTOR)

---

## Chunk 1: Schema Changes + Changeset (TDD)

### Task 1: Add belongs_to association to StaffMemberSchema

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex:12,17-18`

This is a refactor (no new behavior), so TDD cycle is: change → verify existing tests still pass.

- [ ] **Step 1: Add alias for ProviderProfileSchema**

In `staff_member_schema.ex`, add after the existing `alias KlassHero.Shared.Categories` line (line 12):

```elixir
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
```

- [ ] **Step 2: Replace field with belongs_to**

Replace line 18:

```elixir
field :provider_id, :binary_id
```

with:

```elixir
belongs_to :provider, ProviderProfileSchema, type: :binary_id
```

This defines `provider_id` implicitly. No migration needed — the DB column already exists.

- [ ] **Step 3: Run existing tests to verify nothing breaks**

Run: `mix test test/klass_hero/provider/staff_member_integration_test.exs test/klass_hero/provider/domain/models/staff_member_test.exs`

Expected: All tests PASS. The mapper/repository/fixtures all reference `:provider_id` which `belongs_to` still defines.

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex
git commit -m "refactor: replace staff_member provider_id field with belongs_to association

Enables Backpex BelongsTo field to display provider business name
in admin dashboard. No migration needed — DB column unchanged."
```

### Task 2: Add admin_changeset/3 to StaffMemberSchema (TDD: RED → GREEN)

**Files:**
- Create: `test/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema_test.exs`
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex`

- [ ] **Step 1: RED — Write the failing tests**

Create `test/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema_test.exs`:

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema

  describe "admin_changeset/3" do
    setup do
      schema = %StaffMemberSchema{
        id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate(),
        first_name: "Jane",
        last_name: "Doe",
        role: "Instructor",
        email: "jane@example.com",
        bio: "A bio",
        active: true,
        tags: ["sports"],
        qualifications: ["CPR"]
      }

      # Trigger: Backpex passes metadata with assigns as 3rd arg
      # Why: admin_changeset must accept 3-arg signature even if unused
      # Outcome: matches Backpex callback contract
      metadata = [assigns: %{current_scope: %{user: %{id: Ecto.UUID.generate()}}}]

      %{schema: schema, metadata: metadata}
    end

    test "casts active field", %{schema: schema, metadata: metadata} do
      changeset = StaffMemberSchema.admin_changeset(schema, %{"active" => false}, metadata)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :active) == false
    end

    test "ignores non-admin fields", %{schema: schema, metadata: metadata} do
      changeset =
        StaffMemberSchema.admin_changeset(
          schema,
          %{"first_name" => "Hacked", "role" => "CEO", "email" => "hacked@evil.com"},
          metadata
        )

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :first_name)
      refute Ecto.Changeset.get_change(changeset, :role)
      refute Ecto.Changeset.get_change(changeset, :email)
    end

    test "returns valid changeset with no changes", %{schema: schema, metadata: metadata} do
      changeset = StaffMemberSchema.admin_changeset(schema, %{}, metadata)
      assert changeset.valid?
    end
  end
end
```

- [ ] **Step 2: Verify RED — Watch tests fail**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema_test.exs`

Expected: FAIL — `StaffMemberSchema.admin_changeset/3 is undefined`. This confirms the test targets the right function.

- [ ] **Step 3: GREEN — Write minimal implementation**

Add to `staff_member_schema.ex`, after the `edit_changeset/2` function (after line 97):

```elixir
@doc """
Admin changeset for Backpex dashboard edits.

Only allows toggling `active` status — all other fields are provider-owned.
Accepts Backpex 3-arg signature (schema, attrs, metadata); metadata is unused
since no audit trail fields are needed for active toggle.
"""
def admin_changeset(schema, attrs, _metadata) do
  cast(schema, attrs, [:active])
end
```

- [ ] **Step 4: Verify GREEN — Watch tests pass**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema_test.exs`

Expected: All 3 tests PASS.

- [ ] **Step 5: Verify no regressions**

Run: `mix test test/klass_hero/provider/`

Expected: All existing tests PASS alongside the 3 new ones.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex test/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema_test.exs
git commit -m "feat: add admin_changeset/3 to StaffMemberSchema (#339)

TDD: tests written first, then minimal implementation.
Only casts :active field. All other fields remain provider-owned.
Matches Backpex 3-arg callback signature."
```

---

## Chunk 2: LiveView Integration (TDD: RED → GREEN)

Backpex LiveResources are declarative configuration. The TDD cycle here is:
write integration tests → create minimal production code to make them pass.

Note: Elixir's compilation model means the router won't compile without the
referenced module. So the RED phase will produce compilation errors (which is
a valid failure mode per TDD). The GREEN phase creates all production files
together since they form an atomic unit (filter + resource + route + sidebar).

### Task 3: RED — Write all LiveView integration tests

**Files:**
- Create: `test/klass_hero_web/live/admin/staff_live_test.exs`

- [ ] **Step 1: Write the test file**

Create `test/klass_hero_web/live/admin/staff_live_test.exs`:

```elixir
defmodule KlassHeroWeb.Admin.StaffLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/staff", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/staff")
      assert html =~ "Staff Members"
    end

    test "new staff button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/staff")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/staff", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/staff")
      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/staff", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/staff")
    end
  end

  describe "staff member list" do
    setup :register_and_log_in_admin

    test "displays staff members in the table", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Sunny Academy")

      _staff =
        staff_member_fixture(provider_id: provider.id, first_name: "Alice", last_name: "Smith")

      {:ok, view, _html} = live(conn, ~p"/admin/staff")

      assert has_element?(view, "td", "Alice")
      assert has_element?(view, "td", "Smith")
    end

    test "displays provider business name", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Sunny Academy")
      _staff = staff_member_fixture(provider_id: provider.id)

      {:ok, view, _html} = live(conn, ~p"/admin/staff")

      assert has_element?(view, "td", "Sunny Academy")
    end
  end

  describe "edit staff member" do
    setup :register_and_log_in_admin

    test "admin can toggle active status to false", %{conn: conn} do
      provider = provider_profile_fixture()

      staff =
        staff_member_fixture(provider_id: provider.id, first_name: "Bob", last_name: "Jones")

      {:ok, view, _html} = live(conn, ~p"/admin/staff/#{staff.id}/edit")

      view
      |> form("#resource-form", %{change: %{active: false}})
      |> render_submit(%{"save-type" => "save"})

      schema =
        KlassHero.Repo.get!(
          KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema,
          staff.id
        )

      assert schema.active == false
    end

    test "admin cannot edit provider-owned fields", %{conn: conn} do
      provider = provider_profile_fixture()

      staff =
        staff_member_fixture(
          provider_id: provider.id,
          first_name: "Original",
          last_name: "Name",
          role: "Instructor"
        )

      {:ok, view, _html} = live(conn, ~p"/admin/staff/#{staff.id}/edit")

      # Trigger: admin attempts to submit provider-owned field changes
      # Why: admin_changeset only casts :active, so other fields are silently ignored
      # Outcome: first_name, role remain unchanged in the database
      view
      |> form("#resource-form", %{
        change: %{first_name: "Hacked", role: "CEO", active: false}
      })
      |> render_submit(%{"save-type" => "save"})

      schema =
        KlassHero.Repo.get!(
          KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema,
          staff.id
        )

      assert schema.first_name == "Original"
      assert schema.role == "Instructor"
      assert schema.active == false
    end
  end
end
```

- [ ] **Step 2: Verify RED — Confirm tests fail**

Run: `mix test test/klass_hero_web/live/admin/staff_live_test.exs`

Expected: Compilation error — `~p"/admin/staff"` route does not exist (and `StaffLive` module is undefined). This is the correct failure: the feature doesn't exist yet.

### Task 4: GREEN — Create production code to make tests pass

**Files:**
- Create: `lib/klass_hero_web/live/admin/filters/active_filter.ex`
- Create: `lib/klass_hero_web/live/admin/staff_live.ex`
- Modify: `lib/klass_hero_web/router.ex:150`
- Modify: `lib/klass_hero_web/components/layouts/admin.html.heex:34`

All four files form an atomic unit — the route requires the module, the module requires the filter, and the sidebar requires the route.

- [ ] **Step 1: Create the ActiveFilter**

Create `lib/klass_hero_web/live/admin/filters/active_filter.ex`:

```elixir
defmodule KlassHeroWeb.Admin.Filters.ActiveFilter do
  @moduledoc false

  use Backpex.Filters.Boolean

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Active Status"

  @impl Backpex.Filters.Boolean
  def options(_assigns) do
    [
      %{label: "Active", key: "active", predicate: dynamic([x], x.active)},
      %{label: "Inactive", key: "inactive", predicate: dynamic([x], not x.active)}
    ]
  end
end
```

- [ ] **Step 2: Create the StaffLive resource**

Create `lib/klass_hero_web/live/admin/staff_live.ex`:

```elixir
defmodule KlassHeroWeb.Admin.StaffLive do
  @moduledoc """
  Backpex LiveResource for managing staff members in the admin dashboard.

  Provides index, show, and edit views. Only `active` status is editable —
  all other fields are provider-owned.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read + limited edit operations.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema.admin_changeset/3,
      # Required by Backpex even though :new is disabled via can?/3
      create_changeset:
        &KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  # Trigger: :new and :delete are not valid operations for staff members in admin
  # Why: staff members are created/deleted by their providers
  # Outcome: hides "New" button, denies create/delete actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :delete, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true
  def can?(_assigns, :edit, _item), do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def filters do
    [active: %{module: KlassHeroWeb.Admin.Filters.ActiveFilter}]
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Staff Member"

  @impl Backpex.LiveResource
  def plural_name, do: "Staff Members"

  @impl Backpex.LiveResource
  def fields do
    [
      first_name: %{
        module: Backpex.Fields.Text,
        label: "First Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      last_name: %{
        module: Backpex.Fields.Text,
        label: "Last Name",
        searchable: true,
        orderable: true,
        readonly: true
      },
      provider: %{
        module: Backpex.Fields.BelongsTo,
        label: "Provider",
        display_field: :business_name,
        searchable: true,
        orderable: true,
        readonly: true
      },
      role: %{
        module: Backpex.Fields.Text,
        label: "Role",
        searchable: true,
        orderable: true,
        readonly: true
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email",
        searchable: true,
        readonly: true
      },
      active: %{
        module: Backpex.Fields.Boolean,
        label: "Active",
        orderable: true
      },
      bio: %{
        module: Backpex.Fields.Textarea,
        label: "Bio",
        only: [:show],
        readonly: true
      },
      tags: %{
        module: Backpex.Fields.Text,
        label: "Tags",
        only: [:show],
        readonly: true,
        render: fn assigns ->
          ~H"""
          <p>{Enum.join(@value || [], ", ")}</p>
          """
        end
      },
      qualifications: %{
        module: Backpex.Fields.Text,
        label: "Qualifications",
        only: [:show],
        readonly: true,
        render: fn assigns ->
          ~H"""
          <p>{Enum.join(@value || [], ", ")}</p>
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

- [ ] **Step 3: Add the staff route**

In `router.ex`, inside the `:backpex_admin` live_session (after line 150), add:

```elixir
live_resources("/staff", StaffLive, only: [:index, :show, :edit])
```

The `scope "/admin", KlassHeroWeb.Admin` alias (line 137) means this resolves to `KlassHeroWeb.Admin.StaffLive`.

- [ ] **Step 4: Add sidebar nav item**

In `admin.html.heex`, after the Providers sidebar item (after line 34, before `</:sidebar>`), add:

```heex
    <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/staff"}>
      <Backpex.HTML.CoreComponents.icon name="hero-user-group" class="h-5 w-5" /> {gettext(
        "Staff Members"
      )}
    </Backpex.HTML.Layout.sidebar_item>
```

- [ ] **Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`

Expected: Compiles with zero warnings.

- [ ] **Step 6: Verify GREEN — Run the tests**

Run: `mix test test/klass_hero_web/live/admin/staff_live_test.exs`

Expected: All 7 tests PASS (access control + list display + edit behavior).

- [ ] **Step 7: Commit all production + test code together**

```bash
git add lib/klass_hero_web/live/admin/filters/active_filter.ex lib/klass_hero_web/live/admin/staff_live.ex lib/klass_hero_web/router.ex lib/klass_hero_web/components/layouts/admin.html.heex test/klass_hero_web/live/admin/staff_live_test.exs
git commit -m "feat: add staff members to admin dashboard (#339)

TDD: integration tests written first, then production code.
- StaffLive Backpex resource (index/show/edit, active toggle only)
- ActiveFilter for boolean filtering
- BelongsTo provider field with business_name display
- Sidebar navigation with hero-user-group icon

Closes #339"
```

### Task 5: Final verification

- [ ] **Step 1: Run full precommit**

Run: `mix precommit`

Expected: Compilation (warnings-as-errors), formatting, and all tests pass.

- [ ] **Step 2: Fix any issues**

If warnings or test failures, fix and re-run until `mix precommit` is clean.
