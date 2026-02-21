# Bulk Enrollment Domain Gaps Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve 5 schema/domain gaps so the CSV import feature (#176) has a clean foundation.

**Architecture:** Each gap is an independent migration + domain model change. TDD: failing test first, minimal implementation, green, commit. Uses existing DDD/Ports & Adapters layering.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Ecto, PostgreSQL

**Design doc:** `docs/plans/2026-02-21-bulk-enrollment-domain-gaps-design.md`

**Skill:** @idiomatic-elixir — tagged tuples, pattern matching, structs with `@enforce_keys`, changesets at boundaries, functional core.

---

### Task 1: Add `school_name` to Child

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_school_name_to_children.exs`
- Modify: `lib/klass_hero/family/domain/models/child.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/schemas/child_schema.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/mappers/child_mapper.ex`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/change_child.ex`
- Modify: `test/klass_hero/family/domain/models/child_test.exs`
- Modify: `test/klass_hero/family/adapters/driven/persistence/schemas/child_schema_test.exs`

**Step 1: Write failing domain model test**

Add to `test/klass_hero/family/domain/models/child_test.exs`:

```elixir
describe "school_name" do
  test "accepts school_name in new/1" do
    attrs = %{
      id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      first_name: "Alice",
      last_name: "Smith",
      date_of_birth: ~D[2017-03-15],
      school_name: "Berlin International School"
    }

    assert {:ok, child} = Child.new(attrs)
    assert child.school_name == "Berlin International School"
  end

  test "defaults school_name to nil" do
    attrs = %{
      id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      first_name: "Alice",
      last_name: "Smith",
      date_of_birth: ~D[2017-03-15]
    }

    assert {:ok, child} = Child.new(attrs)
    assert is_nil(child.school_name)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/domain/models/child_test.exs --max-failures 1`
Expected: FAIL — `KeyError` because `school_name` is not in the struct.

**Step 3: Update Child domain model**

In `lib/klass_hero/family/domain/models/child.ex`:
- Add `school_name: nil` to `defstruct`
- Add `school_name: String.t() | nil` to `@type t`
- Add `:school_name` to `@moduledoc` fields list
- Update `validate_school_name/2` to accept max 255 chars (optional)

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/family/domain/models/child_test.exs`
Expected: PASS

**Step 5: Write failing schema test**

Add to `test/klass_hero/family/adapters/driven/persistence/schemas/child_schema_test.exs`:

```elixir
test "accepts school_name in form_changeset" do
  changeset =
    ChildSchema.form_changeset(%ChildSchema{}, %{
      first_name: "Alice",
      last_name: "Wonder",
      date_of_birth: ~D[2017-03-15],
      school_name: "Berlin International School"
    })

  assert changeset.valid?
  assert Ecto.Changeset.get_change(changeset, :school_name) == "Berlin International School"
end

test "validates school_name max length" do
  long_name = String.duplicate("a", 256)

  changeset =
    %ChildSchema{}
    |> ChildSchema.form_changeset(%{
      first_name: "Alice",
      last_name: "Wonder",
      date_of_birth: ~D[2017-03-15],
      school_name: long_name
    })
    |> Map.put(:action, :validate)

  refute changeset.valid?
  assert "should be at most 255 character(s)" in errors_on(changeset).school_name
end
```

**Step 6: Run test to verify it fails**

Run: `mix test test/klass_hero/family/adapters/driven/persistence/schemas/child_schema_test.exs --max-failures 1`
Expected: FAIL — `school_name` not in schema/changeset.

**Step 7: Create migration and update schema + mapper + change_child**

Migration:
```elixir
defmodule KlassHero.Repo.Migrations.AddSchoolNameToChildren do
  use Ecto.Migration

  def change do
    alter table(:children) do
      add :school_name, :string, size: 255
    end
  end
end
```

Update `ChildSchema`:
- Add `field :school_name, :string` to schema block
- Add `:school_name` to cast lists in `changeset/2` and `form_changeset/2`
- Add `validate_length(:school_name, max: 255)` to `shared_validations/1`

Update `ChildMapper.to_domain/1`: add `school_name: schema.school_name`
Update `ChildMapper.to_schema/1`: add `school_name: child.school_name`
Update `ChangeChild.child_to_schema/1`: add `school_name: child.school_name`

**Step 8: Run all tests**

Run: `mix test`
Expected: ALL PASS

**Step 9: Commit**

```bash
git add priv/repo/migrations/*add_school_name* lib/klass_hero/family/ test/klass_hero/family/
git commit -m "feat(family): add school_name field to Child (#176)"
```

---

### Task 2: Add `season` to Program

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_season_to_programs.exs`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`
- Create: `test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_season_test.exs`

**Step 1: Write failing schema test**

Create `test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_season_test.exs`:

```elixir
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchemaSeasonTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  @valid_attrs %{
    title: "Ballsports & Parkour",
    description: "A fun sports program",
    category: "sports",
    age_range: "6-10",
    price: Decimal.new("120.00"),
    pricing_period: "semester"
  }

  describe "season field" do
    test "accepts season in changeset" do
      changeset = ProgramSchema.changeset(%ProgramSchema{}, Map.put(@valid_attrs, :season, "Berlin International School 24/25: Semester 2"))

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :season) == "Berlin International School 24/25: Semester 2"
    end

    test "season is optional" do
      changeset = ProgramSchema.changeset(%ProgramSchema{}, @valid_attrs)

      assert changeset.valid?
      assert is_nil(Ecto.Changeset.get_change(changeset, :season))
    end

    test "validates season max length" do
      long_season = String.duplicate("a", 256)
      changeset =
        %ProgramSchema{}
        |> ProgramSchema.changeset(Map.put(@valid_attrs, :season, long_season))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).season
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_season_test.exs --max-failures 1`
Expected: FAIL — `season` not in schema.

**Step 3: Create migration and update ProgramSchema**

Migration:
```elixir
defmodule KlassHero.Repo.Migrations.AddSeasonToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :season, :string, size: 255
    end
  end
end
```

Update `ProgramSchema`:
- Add `field :season, :string` to schema block
- Add `:season` to `@type t`
- Add `:season` to cast lists in `changeset/2`, `create_changeset/2`, `update_changeset/2`
- Add `validate_length(:season, max: 255)` in all three changesets

**Step 4: Run all tests**

Run: `mix test`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add priv/repo/migrations/*add_season* lib/klass_hero/program_catalog/ test/klass_hero/program_catalog/
git commit -m "feat(program_catalog): add season field to Program (#176)"
```

---

### Task 3: Split photo consent types

**Files:**
- Modify: `lib/klass_hero/family/domain/models/consent.ex`
- Modify: `test/klass_hero/family/domain/models/consent_test.exs`

No migration needed — consent_type has no DB check constraint; validation is Elixir-only.

**Step 1: Update test to expect new consent types**

In `test/klass_hero/family/domain/models/consent_test.exs`, update the `valid_consent_types/0` test:

```elixir
test "returns known consent types" do
  types = Consent.valid_consent_types()

  assert is_list(types)
  assert "provider_data_sharing" in types
  assert "photo_marketing" in types
  assert "photo_social_media" in types
  assert "medical" in types
  assert "participation" in types
  refute "photo" in types
end
```

Also update `@valid_attrs` at top of test module:
```elixir
@valid_attrs %{
  ...
  consent_type: "photo_marketing",
  ...
}
```

Update any other test that uses `consent_type: "photo"` to use `"photo_marketing"`.

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/domain/models/consent_test.exs --max-failures 1`
Expected: FAIL — `"photo_marketing"` not in valid types, `"photo"` still present.

**Step 3: Update Consent domain model**

In `lib/klass_hero/family/domain/models/consent.ex`, change:
```elixir
@valid_consent_types ~w(provider_data_sharing photo_marketing photo_social_media medical participation)
```

Update `@moduledoc` to list the new types.

**Step 4: Run all tests**

Run: `mix test`
Expected: ALL PASS — check for any other test files referencing `"photo"` consent type.

**Step 5: Commit**

```bash
git add lib/klass_hero/family/domain/models/consent.ex test/klass_hero/family/domain/models/consent_test.exs
git commit -m "feat(family): split photo consent into photo_marketing and photo_social_media (#176)"
```

---

### Task 4: Children ↔ Guardians many-to-many join table

This is the largest change. It is split into 4 sub-tasks to keep commits green at each step.

#### Task 4a: Create `children_guardians` table and schema (additive)

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_children_guardians.exs`
- Create: `lib/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema.ex`
- Create: `test/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema_test.exs`

**Step 1: Write failing schema test**

Create `test/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema_test.exs`:

```elixir
defmodule KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchema

  describe "changeset/2" do
    test "valid with all required fields" do
      attrs = %{
        child_id: Ecto.UUID.generate(),
        guardian_id: Ecto.UUID.generate(),
        relationship: "parent",
        is_primary: true
      }

      changeset = ChildGuardianSchema.changeset(%ChildGuardianSchema{}, attrs)
      assert changeset.valid?
    end

    test "requires child_id and guardian_id" do
      changeset =
        %ChildGuardianSchema{}
        |> ChildGuardianSchema.changeset(%{})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).child_id
      assert errors_on(changeset).guardian_id
    end

    test "validates relationship inclusion" do
      attrs = %{
        child_id: Ecto.UUID.generate(),
        guardian_id: Ecto.UUID.generate(),
        relationship: "invalid_value"
      }

      changeset =
        %ChildGuardianSchema{}
        |> ChildGuardianSchema.changeset(attrs)
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).relationship
    end

    test "defaults relationship to parent and is_primary to false" do
      attrs = %{
        child_id: Ecto.UUID.generate(),
        guardian_id: Ecto.UUID.generate()
      }

      changeset = ChildGuardianSchema.changeset(%ChildGuardianSchema{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :relationship) == "parent"
      assert Ecto.Changeset.get_field(changeset, :is_primary) == false
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema_test.exs --max-failures 1`
Expected: FAIL — module does not exist.

**Step 3: Create migration and schema**

Migration:
```elixir
defmodule KlassHero.Repo.Migrations.CreateChildrenGuardians do
  use Ecto.Migration

  def change do
    create table(:children_guardians, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :child_id, references(:children, type: :binary_id, on_delete: :delete_all), null: false
      add :guardian_id, references(:parents, type: :binary_id, on_delete: :delete_all), null: false
      add :relationship, :string, size: 50, null: false, default: "parent"
      add :is_primary, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:children_guardians, [:child_id, :guardian_id])
    create index(:children_guardians, [:guardian_id])
  end
end
```

Schema `lib/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema.ex`:
```elixir
defmodule KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchema do
  @moduledoc """
  Ecto schema for the children_guardians join table.

  Links children to their guardians (parents, legal guardians, etc.)
  in a many-to-many relationship. Each link records the relationship type
  and whether this guardian is the primary contact.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_relationships ~w(parent guardian other)

  schema "children_guardians" do
    field :child_id, :binary_id
    field :guardian_id, :binary_id
    field :relationship, :string, default: "parent"
    field :is_primary, :boolean, default: false

    timestamps()
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:child_id, :guardian_id, :relationship, :is_primary])
    |> validate_required([:child_id, :guardian_id])
    |> validate_inclusion(:relationship, @valid_relationships)
    |> unique_constraint([:child_id, :guardian_id],
      name: :children_guardians_child_id_guardian_id_index
    )
    |> foreign_key_constraint(:child_id)
    |> foreign_key_constraint(:guardian_id)
  end

  def valid_relationships, do: @valid_relationships
end
```

**Step 4: Run all tests**

Run: `mix test`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add priv/repo/migrations/*create_children_guardians* lib/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema.ex test/klass_hero/family/adapters/driven/persistence/schemas/child_guardian_schema_test.exs
git commit -m "feat(family): add children_guardians join table (#176)"
```

#### Task 4b: Migrate existing `parent_id` data into join table

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_migrate_children_parent_id_to_guardians.exs`

**Step 1: Create data migration**

```elixir
defmodule KlassHero.Repo.Migrations.MigrateChildrenParentIdToGuardians do
  use Ecto.Migration

  def up do
    # Trigger: existing children have parent_id FK, new join table is empty
    # Why: preserve existing parent-child relationships in the new structure
    # Outcome: every child gets a primary guardian row in children_guardians
    execute """
    INSERT INTO children_guardians (id, child_id, guardian_id, relationship, is_primary, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      c.id,
      c.parent_id,
      'parent',
      true,
      NOW(),
      NOW()
    FROM children c
    WHERE c.parent_id IS NOT NULL
    """
  end

  def down do
    execute "DELETE FROM children_guardians"
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully.

**Step 3: Verify data**

Use Tidewave: `execute_sql_query("SELECT COUNT(*) FROM children_guardians")`
Expected: Same count as `SELECT COUNT(*) FROM children WHERE parent_id IS NOT NULL`

**Step 4: Commit**

```bash
git add priv/repo/migrations/*migrate_children_parent_id*
git commit -m "chore(family): migrate children.parent_id data to children_guardians (#176)"
```

#### Task 4c: Update domain code to use join table

**Files:**
- Modify: `lib/klass_hero/family/domain/models/child.ex` — remove `parent_id` from `@enforce_keys`, add `guardian_ids: []`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/schemas/child_schema.ex` — remove `parent_id` field, remove FK constraint
- Modify: `lib/klass_hero/family/adapters/driven/persistence/mappers/child_mapper.ex` — remove `parent_id` mapping
- Modify: `lib/klass_hero/family/adapters/driven/persistence/repositories/child_repository.ex` — `list_by_parent` joins through `children_guardians`
- Modify: `lib/klass_hero/family/adapters/driven/persistence/change_child.ex` — remove `parent_id`
- Modify: `lib/klass_hero/family/domain/ports/for_storing_children.ex` — rename `list_by_parent` → `list_by_guardian`
- Modify: `lib/klass_hero/family.ex` — update `get_children`, `child_belongs_to_parent?`, GDPR functions
- Modify: All affected tests

**Step 1: Write failing repository test**

Update `test/klass_hero/family/adapters/driven/persistence/repositories/child_repository_test.exs` to use the join table for `list_by_guardian`. The test should:
- Insert a child (no parent_id on child)
- Insert a children_guardians row linking child → guardian
- Call `list_by_guardian(guardian_id)` and assert the child is returned

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/adapters/driven/persistence/repositories/child_repository_test.exs --max-failures 1`
Expected: FAIL — `list_by_guardian` does not exist.

**Step 3: Update all domain code**

This is the largest code change. Key modifications:

**Child domain model** (`child.ex`):
- Remove `:parent_id` from `@enforce_keys`
- Remove `parent_id` from struct and `@type t`
- Remove `validate_parent_id` from validation chain
- The child no longer "knows" its parent — that relationship lives in the join table

**ChildSchema** (`child_schema.ex`):
- Remove `field :parent_id, :binary_id`
- Remove `:parent_id` from all cast/validate_required calls
- Remove `foreign_key_constraint(:parent_id)`

**ChildMapper** (`child_mapper.ex`):
- Remove `parent_id` from `to_domain` and `to_schema` mappings

**ChildRepository** (`child_repository.ex`):
- Rename `list_by_parent` → `list_by_guardian`
- Change query to join through `children_guardians`:
```elixir
def list_by_guardian(guardian_id) when is_binary(guardian_id) do
  ChildSchema
  |> join(:inner, [c], cg in "children_guardians", on: c.id == cg.child_id)
  |> where([c, cg], cg.guardian_id == ^guardian_id)
  |> order_by([c], asc: c.first_name, asc: c.last_name)
  |> Repo.all()
  |> ChildMapper.to_domain_list()
end
```

**ForStoringChildren port** (`for_storing_children.ex`):
- Rename `list_by_parent` → `list_by_guardian` callback

**Family context** (`family.ex`):
- Update `get_children/1` to call `list_by_guardian`
- Update `child_belongs_to_parent?/2` to query join table
- Update GDPR `anonymize_data_for_user` and `export_data_for_user` to use join table
- Update `get_child_ids_for_parent/1`

**ChangeChild** (`change_child.ex`):
- Remove `parent_id` from `child_to_schema`

**Step 4: Run all tests, fix remaining failures**

Run: `mix test`
Expected: Multiple failures from tests that still reference `parent_id` on children. Fix each one:
- Tests creating children need to create via `ChildSchema` (without parent_id) + `ChildGuardianSchema` row
- Tests checking `child.parent_id` need updating

**Step 5: Commit**

```bash
git add lib/klass_hero/family/ test/klass_hero/family/
git commit -m "refactor(family): replace children.parent_id with children_guardians join (#176)"
```

#### Task 4d: Drop `parent_id` column from children

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_drop_parent_id_from_children.exs`

**Step 1: Create migration**

```elixir
defmodule KlassHero.Repo.Migrations.DropParentIdFromChildren do
  use Ecto.Migration

  def up do
    drop index(:children, [:parent_id])

    alter table(:children) do
      remove :parent_id
    end
  end

  def down do
    alter table(:children) do
      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict)
    end

    create index(:children, [:parent_id])

    # Trigger: restoring parent_id from join table for rollback
    # Why: down migration must restore the previous schema state
    # Outcome: first primary guardian becomes the parent_id
    execute """
    UPDATE children c
    SET parent_id = cg.guardian_id
    FROM children_guardians cg
    WHERE cg.child_id = c.id AND cg.is_primary = true
    """
  end
end
```

**Step 2: Run migration and full test suite**

Run: `mix ecto.migrate && mix test`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add priv/repo/migrations/*drop_parent_id*
git commit -m "chore(family): drop parent_id column from children table (#176)"
```

---

### Task 5: Create `BulkEnrollmentInvite` schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_bulk_enrollment_invites.exs`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema_test.exs`

**Step 1: Write failing schema test**

Create `test/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema_test.exs`:

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema

  @valid_attrs %{
    program_id: Ecto.UUID.generate(),
    provider_id: Ecto.UUID.generate(),
    child_first_name: "Avyan",
    child_last_name: "Srivastava",
    child_date_of_birth: ~D[2016-01-01],
    guardian_email: "parent@example.com",
    guardian_first_name: "Vaibhav",
    guardian_last_name: "Srivastava",
    status: "pending"
  }

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(%{})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).program_id
      assert errors_on(changeset).provider_id
      assert errors_on(changeset).child_first_name
      assert errors_on(changeset).child_last_name
      assert errors_on(changeset).child_date_of_birth
      assert errors_on(changeset).guardian_email
    end

    test "validates status inclusion" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(Map.put(@valid_attrs, :status, "invalid"))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).status
    end

    test "validates guardian_email format" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(Map.put(@valid_attrs, :guardian_email, "not-an-email"))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).guardian_email
    end

    test "accepts optional second guardian fields" do
      attrs = Map.merge(@valid_attrs, %{
        guardian2_email: "parent2@example.com",
        guardian2_first_name: "Alex",
        guardian2_last_name: "Srivastava"
      })

      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert changeset.valid?
    end

    test "accepts optional medical and consent fields" do
      attrs = Map.merge(@valid_attrs, %{
        school_grade: 3,
        school_name: "Berlin International School",
        medical_conditions: "Asthma",
        nut_allergy: true,
        consent_photo_marketing: true,
        consent_photo_social_media: false
      })

      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert changeset.valid?
    end

    test "validates school_grade range" do
      changeset =
        %BulkEnrollmentInviteSchema{}
        |> BulkEnrollmentInviteSchema.changeset(Map.put(@valid_attrs, :school_grade, 14))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).school_grade
    end

    test "defaults status to pending" do
      attrs = Map.delete(@valid_attrs, :status)
      changeset = BulkEnrollmentInviteSchema.changeset(%BulkEnrollmentInviteSchema{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema_test.exs --max-failures 1`
Expected: FAIL — module does not exist.

**Step 3: Create migration and schema**

Migration:
```elixir
defmodule KlassHero.Repo.Migrations.CreateBulkEnrollmentInvites do
  use Ecto.Migration

  def change do
    create table(:bulk_enrollment_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false
      add :provider_id, references(:provider_profiles, type: :binary_id, on_delete: :restrict), null: false

      # Child info (denormalized from CSV)
      add :child_first_name, :string, size: 100, null: false
      add :child_last_name, :string, size: 100, null: false
      add :child_date_of_birth, :date, null: false

      # Primary guardian
      add :guardian_email, :string, size: 160, null: false
      add :guardian_first_name, :string, size: 100
      add :guardian_last_name, :string, size: 100

      # Secondary guardian (optional)
      add :guardian2_email, :string, size: 160
      add :guardian2_first_name, :string, size: 100
      add :guardian2_last_name, :string, size: 100

      # School info
      add :school_grade, :integer
      add :school_name, :string, size: 255

      # Medical info
      add :medical_conditions, :text
      add :nut_allergy, :boolean, default: false, null: false

      # Consent flags
      add :consent_photo_marketing, :boolean, default: false, null: false
      add :consent_photo_social_media, :boolean, default: false, null: false

      # Invite lifecycle
      add :status, :string, size: 50, null: false, default: "pending"
      add :invite_token, :string
      add :invite_sent_at, :utc_datetime
      add :registered_at, :utc_datetime
      add :enrolled_at, :utc_datetime
      add :enrollment_id, references(:enrollments, type: :binary_id, on_delete: :nilify_all)
      add :error_details, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bulk_enrollment_invites, [:invite_token], where: "invite_token IS NOT NULL")
    create unique_index(:bulk_enrollment_invites, [:program_id, :guardian_email, :child_first_name, :child_last_name],
      name: :bulk_invites_program_guardian_child_unique
    )
    create index(:bulk_enrollment_invites, [:program_id])
    create index(:bulk_enrollment_invites, [:provider_id])
    create index(:bulk_enrollment_invites, [:status])

    create constraint(:bulk_enrollment_invites, :valid_status,
      check: "status IN ('pending', 'invite_sent', 'registered', 'enrolled', 'failed')"
    )
    create constraint(:bulk_enrollment_invites, :valid_school_grade,
      check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
    )
  end
end
```

Schema `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema.ex`:
```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema do
  @moduledoc """
  Ecto schema for the bulk_enrollment_invites table.

  Stores denormalized CSV data as a staging record for bulk enrollment.
  When a parent acts on the invite, real domain entities (User, ParentProfile,
  Child, Enrollment, Consents) are created from this data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(pending invite_sent registered enrolled failed)

  schema "bulk_enrollment_invites" do
    field :program_id, :binary_id
    field :provider_id, :binary_id
    field :child_first_name, :string
    field :child_last_name, :string
    field :child_date_of_birth, :date
    field :guardian_email, :string
    field :guardian_first_name, :string
    field :guardian_last_name, :string
    field :guardian2_email, :string
    field :guardian2_first_name, :string
    field :guardian2_last_name, :string
    field :school_grade, :integer
    field :school_name, :string
    field :medical_conditions, :string
    field :nut_allergy, :boolean, default: false
    field :consent_photo_marketing, :boolean, default: false
    field :consent_photo_social_media, :boolean, default: false
    field :status, :string, default: "pending"
    field :invite_token, :string
    field :invite_sent_at, :utc_datetime
    field :registered_at, :utc_datetime
    field :enrolled_at, :utc_datetime
    field :enrollment_id, :binary_id
    field :error_details, :string

    timestamps()
  end

  @required_fields ~w(program_id provider_id child_first_name child_last_name child_date_of_birth guardian_email)a

  @optional_fields ~w(
    guardian_first_name guardian_last_name
    guardian2_email guardian2_first_name guardian2_last_name
    school_grade school_name medical_conditions nut_allergy
    consent_photo_marketing consent_photo_social_media
    status invite_token invite_sent_at registered_at enrolled_at
    enrollment_id error_details
  )a

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:child_first_name, min: 1, max: 100)
    |> validate_length(:child_last_name, min: 1, max: 100)
    |> validate_length(:guardian_email, max: 160)
    |> validate_format(:guardian_email, ~r/^[^@,;\s]+@[^@,;\s]+$/, message: "must be a valid email")
    |> validate_length(:guardian_first_name, max: 100)
    |> validate_length(:guardian_last_name, max: 100)
    |> validate_length(:guardian2_email, max: 160)
    |> maybe_validate_guardian2_email()
    |> validate_length(:guardian2_first_name, max: 100)
    |> validate_length(:guardian2_last_name, max: 100)
    |> validate_length(:school_name, max: 255)
    |> validate_number(:school_grade, greater_than_or_equal_to: 1, less_than_or_equal_to: 13)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:program_id, :guardian_email, :child_first_name, :child_last_name],
      name: :bulk_invites_program_guardian_child_unique
    )
    |> unique_constraint(:invite_token)
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:enrollment_id)
    |> check_constraint(:status, name: :valid_status)
    |> check_constraint(:school_grade, name: :valid_school_grade)
  end

  def valid_statuses, do: @valid_statuses

  # Trigger: guardian2_email is present and non-nil
  # Why: if a second guardian email is provided, it must be valid
  # Outcome: format validation applied only when field has a value
  defp maybe_validate_guardian2_email(changeset) do
    case get_field(changeset, :guardian2_email) do
      nil -> changeset
      "" -> changeset
      _email -> validate_format(changeset, :guardian2_email, ~r/^[^@,;\s]+@[^@,;\s]+$/, message: "must be a valid email")
    end
  end
end
```

**Step 4: Run all tests**

Run: `mix test`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add priv/repo/migrations/*create_bulk_enrollment* lib/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema.ex test/klass_hero/enrollment/adapters/driven/persistence/schemas/bulk_enrollment_invite_schema_test.exs
git commit -m "feat(enrollment): add BulkEnrollmentInvite schema (#176)"
```

---

### Task 6: Final verification

**Step 1: Run full precommit checks**

Run: `mix precommit`
Expected: Compile (0 warnings), format (clean), test (ALL PASS)

**Step 2: Verify migration rollback**

Run: `mix ecto.rollback --step 5 && mix ecto.migrate`
Expected: Clean rollback and re-migration with no errors.

**Step 3: Commit any formatting fixes**

```bash
git add -A && git commit -m "style: mix format"
```
(Only if `mix format` changed files.)
