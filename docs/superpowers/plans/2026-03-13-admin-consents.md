# Admin Consents Overview Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read-only Backpex admin page for viewing consent records with search, filters, status badges, and a compliance banner.

**Architecture:** Backpex LiveResource on `ConsentSchema` with `belongs_to` associations for child/parent display. Two `Backpex.Filters.Select` filters (consent type, consent status). TDD throughout — tests first, then implementation.

**Tech Stack:** Elixir, Phoenix LiveView, Backpex, Ecto, ExMachina

**Spec:** `docs/superpowers/specs/2026-03-13-admin-consents-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/klass_hero/family/adapters/driven/persistence/schemas/consent_schema.ex` | Add `belongs_to` associations + `admin_changeset/3` |
| Create | `lib/klass_hero_web/live/admin/consent_live.ex` | Backpex LiveResource (index + show) |
| Create | `lib/klass_hero_web/live/admin/filters/consent_type_filter.ex` | Select filter for consent type |
| Create | `lib/klass_hero_web/live/admin/filters/consent_status_filter.ex` | Select filter for active/withdrawn |
| Modify | `lib/klass_hero_web/router.ex` | Add `live_resources` route |
| Modify | `test/support/factory.ex` | Update factory for `belongs_to` associations |
| Create | `test/klass_hero_web/live/admin/consent_live_test.exs` | LiveView tests |

---

## Chunk 1: Schema Changes + Factory

### Task 1: Add `belongs_to` associations and `admin_changeset/3` to ConsentSchema

**Files:**
- Modify: `lib/klass_hero/family/adapters/driven/persistence/schemas/consent_schema.ex`

- [ ] **Step 1: Run existing consent tests to confirm green baseline**

Run: `mix test test/klass_hero/family/ --max-failures 3`
Expected: All pass.

- [ ] **Step 2: Modify ConsentSchema — replace fields with `belongs_to`, add `admin_changeset/3`**

In `lib/klass_hero/family/adapters/driven/persistence/schemas/consent_schema.ex`, replace the two plain fields with associations and add the no-op changeset:

```elixir
# Replace these two lines:
#   field :parent_id, :binary_id
#   field :child_id, :binary_id
# With:
belongs_to :parent,
           KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema

belongs_to :child,
           KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
```

Add at the bottom of the module, before `end`:

```elixir
@doc """
No-op changeset required by Backpex even when edit is disabled via `can?/3`.
"""
def admin_changeset(schema, _attrs, _metadata), do: change(schema)
```

- [ ] **Step 3: Run existing consent tests to verify nothing broke**

Run: `mix test test/klass_hero/family/ --max-failures 3`
Expected: All pass. The `belongs_to` macro defines the same `parent_id` / `child_id` fields, so existing code continues to work.

- [ ] **Step 4: Compile with warnings-as-errors**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/family/adapters/driven/persistence/schemas/consent_schema.ex
git commit -m "refactor: add belongs_to associations and admin_changeset to ConsentSchema (#341)"
```

### Task 2: Update consent factory for `belongs_to` associations

**Files:**
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Update `consent_schema_factory` to include association structs alongside IDs**

In `test/support/factory.ex`, update `consent_schema_factory/0`. Keep explicit `_id` fields (Ecto struct assignment does NOT auto-populate foreign keys) and add the association structs so Backpex preloads work in tests:

```elixir
def consent_schema_factory do
  {child_schema, parent_schema} = insert_child_with_guardian()

  %ConsentSchema{
    id: Ecto.UUID.generate(),
    parent: parent_schema,
    parent_id: parent_schema.id,
    child: child_schema,
    child_id: child_schema.id,
    consent_type: "provider_data_sharing",
    granted_at: DateTime.utc_now() |> DateTime.truncate(:second),
    withdrawn_at: nil
  }
end
```

- [ ] **Step 2: Run existing consent tests to verify factory still works**

Run: `mix test test/klass_hero/family/ --max-failures 3`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add test/support/factory.ex
git commit -m "test: update consent factory for belongs_to associations (#341)"
```

---

## Chunk 2: Filters

### Task 3: Create ConsentTypeFilter

**Files:**
- Create: `lib/klass_hero_web/live/admin/filters/consent_type_filter.ex`

- [ ] **Step 1: Create the filter module**

Follows existing pattern from `StatusFilter` but uses `Backpex.Filters.Select` since consent type is a single-value select:

```elixir
defmodule KlassHeroWeb.Admin.Filters.ConsentTypeFilter do
  @moduledoc false

  use Backpex.Filters.Select

  alias KlassHero.Family.Domain.Models.Consent

  @impl Backpex.Filter
  def label, do: "Consent Type"

  @impl Backpex.Filters.Select
  def prompt, do: "All types..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    Consent.valid_consent_types()
    |> Enum.map(fn type -> {humanize_consent_type(type), type} end)
  end

  defp humanize_consent_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
```

- [ ] **Step 2: Compile**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero_web/live/admin/filters/consent_type_filter.ex
git commit -m "feat: add ConsentTypeFilter for admin consents (#341)"
```

### Task 4: Create ConsentStatusFilter

**Files:**
- Create: `lib/klass_hero_web/live/admin/filters/consent_status_filter.ex`

- [ ] **Step 1: Create the filter module**

Uses `Backpex.Filters.Select` with custom `query/4` override because filtering on `IS NULL` / `IS NOT NULL` can't use the default equality check:

```elixir
defmodule KlassHeroWeb.Admin.Filters.ConsentStatusFilter do
  @moduledoc false

  use Backpex.Filters.Select

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Status"

  @impl Backpex.Filters.Select
  def prompt, do: "All statuses..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    [
      {"Active", "active"},
      {"Withdrawn", "withdrawn"}
    ]
  end

  # Trigger: default Select filter uses equality on the attribute column
  # Why: status is derived from withdrawn_at being NULL or NOT NULL, not a direct field value
  # Outcome: custom WHERE clause checking withdrawn_at nullability
  @impl Backpex.Filter
  def query(query, _attribute, "active", _assigns) do
    where(query, [x], is_nil(x.withdrawn_at))
  end

  def query(query, _attribute, "withdrawn", _assigns) do
    where(query, [x], not is_nil(x.withdrawn_at))
  end
end
```

- [ ] **Step 2: Compile**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero_web/live/admin/filters/consent_status_filter.ex
git commit -m "feat: add ConsentStatusFilter for admin consents (#341)"
```

---

## Chunk 3: ConsentLive + Router (TDD)

### Task 5: Write failing tests for ConsentLive

**Files:**
- Create: `test/klass_hero_web/live/admin/consent_live_test.exs`

- [ ] **Step 1: Write the test file**

Follow the established pattern from `booking_live_test.exs`. Includes access control, list rendering, show page, search, and filter tests:

```elixir
defmodule KlassHeroWeb.Admin.ConsentLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/consents", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Consents"
    end

    test "new consent button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/consents", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/admin/consents")

      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/consents", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/consents")
    end
  end

  describe "consent list" do
    setup :register_and_log_in_admin

    test "displays consent records in the table", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "medical")

      child =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema,
          consent.child_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      assert has_element?(view, "td", child.first_name)
      assert has_element?(view, "td", "Medical")
    end

    test "displays active status badge for active consent", %{conn: conn} do
      insert(:consent_schema, withdrawn_at: nil)
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Active"
    end

    test "displays withdrawn status badge for withdrawn consent", %{conn: conn} do
      insert(:consent_schema,
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Withdrawn"
    end

    test "displays compliance banner", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "append-only"
    end

    test "search by child name returns matching results", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "medical")

      child =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema,
          consent.child_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => child.first_name}})

      assert has_element?(view, "td", child.first_name)
    end

    test "search by parent display name returns matching results", %{conn: conn} do
      consent = insert(:consent_schema)

      parent =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema,
          consent.parent_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => parent.display_name}})

      assert has_element?(view, "td", parent.display_name)
    end
  end

  describe "consent show" do
    setup :register_and_log_in_admin

    test "displays consent detail with granted_at", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "photo_marketing")
      {:ok, _view, html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      assert html =~ "Photo Marketing"
    end

    test "displays withdrawn_at on show page", %{conn: conn} do
      withdrawn_at = ~U[2026-02-15 10:30:00Z]

      consent =
        insert(:consent_schema,
          consent_type: "medical",
          withdrawn_at: withdrawn_at
        )

      {:ok, _view, html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      assert html =~ "Withdrawn"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero_web/live/admin/consent_live_test.exs --max-failures 1`
Expected: FAIL — route doesn't exist yet.

- [ ] **Step 3: Commit failing tests**

```bash
git add test/klass_hero_web/live/admin/consent_live_test.exs
git commit -m "test: add failing tests for admin consent LiveView (#341)"
```

### Task 6: Add route and implement ConsentLive

**Files:**
- Modify: `lib/klass_hero_web/router.ex:153`
- Create: `lib/klass_hero_web/live/admin/consent_live.ex`

Note: Route and module are created together to avoid a broken intermediate commit (the router references the module at compile time).

- [ ] **Step 1: Add `live_resources` for consents in router**

In `lib/klass_hero_web/router.ex`, inside the `:backpex_admin` live_session (after line 153, the bookings route), add:

```elixir
live_resources("/consents", ConsentLive, only: [:index, :show])
```

- [ ] **Step 2: Create the ConsentLive Backpex resource**

```elixir
defmodule KlassHeroWeb.Admin.ConsentLive do
  @moduledoc """
  Backpex LiveResource for viewing consent records in the admin dashboard.

  Read-only overview — no grant, withdraw, or delete actions. Consent records
  are append-only for compliance; withdrawals are recorded with timestamps
  and records are never deleted.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read operations.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema.admin_changeset/3,
      create_changeset:
        &KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  import Ecto.Query

  # Trigger: all mutation actions denied — this is a read-only compliance view
  # Why: consents are granted/withdrawn by parents, not admins
  # Outcome: hides New button, denies edit/delete/new actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :edit, _item), do: false
  def can?(_assigns, :delete, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true
  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def singular_name, do: "Consent"

  @impl Backpex.LiveResource
  def plural_name, do: "Consents"

  @impl Backpex.LiveResource
  def filters do
    [
      consent_type: %{module: KlassHeroWeb.Admin.Filters.ConsentTypeFilter},
      withdrawn_at: %{module: KlassHeroWeb.Admin.Filters.ConsentStatusFilter}
    ]
  end

  @impl Backpex.LiveResource
  def item_query(query, _live_action, _assigns) do
    from c in query, preload: [:child, :parent]
  end

  # Trigger: index page renders — show compliance context
  # Why: admins need to understand that consent records are immutable audit trails
  # Outcome: info banner displayed above the main table
  @impl Backpex.LiveResource
  def render_resource_slot(assigns, :index, :before_main) do
    ~H"""
    <div class="mb-4 rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm text-blue-800">
      Consent records are append-only for compliance. Withdrawals are recorded
      with timestamps — records are never deleted.
    </div>
    """
  end

  @impl Backpex.LiveResource
  def fields do
    [
      child: %{
        module: Backpex.Fields.BelongsTo,
        label: "Child",
        display_field: :first_name,
        searchable: true,
        only: [:index, :show],
        render: fn assigns ->
          ~H"""
          <span>
            <%= if @value do %>
              {@value.first_name} {@value.last_name}
            <% else %>
              <span class="text-gray-400 italic">Deleted</span>
            <% end %>
          </span>
          """
        end
      },
      parent: %{
        module: Backpex.Fields.BelongsTo,
        label: "Parent",
        display_field: :display_name,
        searchable: true,
        only: [:index, :show]
      },
      consent_type: %{
        module: Backpex.Fields.Text,
        label: "Type",
        searchable: true,
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span>{humanize_consent_type(@value)}</span>
          """
        end
      },
      status: %{
        module: Backpex.Fields.Text,
        label: "Status",
        only: [:index, :show],
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
            status_badge_class(@item)
          ]}>
            {status_label(@item)}
          </span>
          """
        end
      },
      granted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Granted At",
        orderable: true
      },
      withdrawn_at: %{
        module: Backpex.Fields.DateTime,
        label: "Withdrawn At",
        only: [:show]
      }
    ]
  end

  defp humanize_consent_type(type) when is_binary(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp humanize_consent_type(_), do: "—"

  defp status_badge_class(%{withdrawn_at: nil}), do: "bg-green-100 text-green-800"
  defp status_badge_class(%{withdrawn_at: _}), do: "bg-amber-100 text-amber-800"

  defp status_label(%{withdrawn_at: nil}), do: "Active"
  defp status_label(%{withdrawn_at: _}), do: "Withdrawn"
end
```

- [ ] **Step 3: Compile**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile.

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero_web/live/admin/consent_live_test.exs`
Expected: All pass.

- [ ] **Step 5: Run full test suite**

Run: `mix test --max-failures 5`
Expected: All pass (existing consent tests still green).

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/router.ex lib/klass_hero_web/live/admin/consent_live.ex
git commit -m "feat: add read-only admin consent overview with Backpex (#341)"
```

---

## Chunk 4: Pre-commit + Final Verification

### Task 7: Run pre-commit checks and verify

- [ ] **Step 1: Run full pre-commit suite**

Run: `mix precommit`
Expected: All checks pass (compile with warnings-as-errors, format, test).

- [ ] **Step 2: Fix any issues found**

If format changes are needed, stage and commit them.

- [ ] **Step 3: Verify the feature manually via Playwright or browser**

Navigate to `http://localhost:4000/admin/consents` and verify:
- Index page loads with compliance banner
- Consent records display child name, parent name, type, status badge
- Filters for consent type and status work
- Show page displays full details including withdrawn_at

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address pre-commit findings for admin consents (#341)"
```
