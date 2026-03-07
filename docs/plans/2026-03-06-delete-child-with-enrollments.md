# Delete Child with Active Enrollments — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix #298 — allow parents to delete a child even when they have active enrollments, with a confirmation warning showing enrolled programs.

**Architecture:** Family context uses ACL adapters (direct DB queries) to clean up enrollment and participation data before deleting a child. This avoids Boundary dependency cycles since both Enrollment and Participation already depend on Family. Two new Family ports define what Family needs; ACL adapters implement them with direct table queries — the established pattern (see `ProgramCatalogACL` in Enrollment).

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL

---

### Task 1: Enrollment cleanup — port + ACL adapter

**Files:**
- Create: `lib/klass_hero/family/domain/ports/for_managing_child_enrollments.ex`
- Create: `lib/klass_hero/family/adapters/driven/acl/child_enrollment_acl.ex`
- Modify: `config/config.exs:97-104` (family config)
- Test: `test/klass_hero/family/adapters/driven/acl/child_enrollment_acl_test.exs`

**Step 1: Write the port behaviour**

```elixir
# lib/klass_hero/family/domain/ports/for_managing_child_enrollments.ex
defmodule KlassHero.Family.Domain.Ports.ForManagingChildEnrollments do
  @moduledoc """
  Port for managing enrollment data when deleting a child.

  Family needs to query and cancel enrollments but cannot depend on
  the Enrollment context (which already depends on Family). This port
  is implemented by an ACL adapter that queries the enrollments table directly.
  """

  @type active_enrollment :: %{
          enrollment_id: String.t(),
          program_id: String.t(),
          program_title: String.t(),
          status: String.t()
        }

  @doc "Lists active enrollments for a child with program titles."
  @callback list_active_with_program_titles(child_id :: binary()) :: [active_enrollment()]

  @doc "Cancels all active enrollments for a child. Returns count of cancelled rows."
  @callback cancel_active_for_child(child_id :: binary()) :: {:ok, non_neg_integer()}
end
```

**Step 2: Write the failing ACL adapter test**

```elixir
# test/klass_hero/family/adapters/driven/acl/child_enrollment_acl_test.exs
defmodule KlassHero.Family.Adapters.Driven.Enrollment.ChildEnrollmentACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Adapters.Driven.Enrollment.ChildEnrollmentACL

  describe "list_active_with_program_titles/1" do
    test "returns active enrollments with program titles" do
      program = insert(:program_schema, title: "Soccer Camp")
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      result = ChildEnrollmentACL.list_active_with_program_titles(child.id)

      assert [%{program_title: "Soccer Camp", status: "confirmed"}] = result
    end

    test "excludes cancelled and completed enrollments" do
      program = insert(:program_schema)
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "cancelled"
      )

      assert [] = ChildEnrollmentACL.list_active_with_program_titles(child.id)
    end

    test "returns empty list when no enrollments exist" do
      {child, _parent} = insert_child_with_guardian()

      assert [] = ChildEnrollmentACL.list_active_with_program_titles(child.id)
    end
  end

  describe "cancel_active_for_child/1" do
    test "cancels all active enrollments and returns count" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program1.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

      insert(:enrollment_schema,
        program_id: program2.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, 2} = ChildEnrollmentACL.cancel_active_for_child(child.id)

      # Verify they're cancelled
      assert [] = ChildEnrollmentACL.list_active_with_program_titles(child.id)
    end

    test "does not cancel already cancelled enrollments" do
      program = insert(:program_schema)
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "cancelled"
      )

      assert {:ok, 0} = ChildEnrollmentACL.cancel_active_for_child(child.id)
    end

    test "returns zero count when no enrollments exist" do
      {child, _parent} = insert_child_with_guardian()

      assert {:ok, 0} = ChildEnrollmentACL.cancel_active_for_child(child.id)
    end
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `mix test test/klass_hero/family/adapters/driven/acl/child_enrollment_acl_test.exs`
Expected: Compilation error — module `ChildEnrollmentACL` does not exist

**Step 4: Implement the ACL adapter**

```elixir
# lib/klass_hero/family/adapters/driven/acl/child_enrollment_acl.ex
defmodule KlassHero.Family.Adapters.Driven.Enrollment.ChildEnrollmentACL do
  @moduledoc """
  ACL adapter that manages enrollment data for child deletion.

  Queries the `enrollments` and `programs` tables directly to avoid
  a dependency cycle (Enrollment already depends on Family).
  """

  @behaviour KlassHero.Family.Domain.Ports.ForManagingChildEnrollments

  import Ecto.Query, only: [from: 2]

  alias KlassHero.Repo

  @active_statuses ~w(pending confirmed)

  @impl true
  def list_active_with_program_titles(child_id) when is_binary(child_id) do
    from(e in "enrollments",
      join: p in "programs",
      on: e.program_id == p.id,
      where: e.child_id == type(^child_id, :binary_id),
      where: e.status in ^@active_statuses,
      select: %{
        enrollment_id: type(e.id, :binary_id),
        program_id: type(e.program_id, :binary_id),
        program_title: p.title,
        status: e.status
      }
    )
    |> Repo.all()
  end

  @impl true
  def cancel_active_for_child(child_id) when is_binary(child_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      from(e in "enrollments",
        where: e.child_id == type(^child_id, :binary_id),
        where: e.status in ^@active_statuses
      )
      |> Repo.update_all(set: [status: "cancelled", cancelled_at: now, updated_at: now])

    {:ok, count}
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/family/adapters/driven/acl/child_enrollment_acl_test.exs`
Expected: All 6 tests pass

**Step 6: Wire up config**

Add to the `:family` config block in `config/config.exs` (after line 104):

```elixir
config :klass_hero, :family,
  repo: KlassHero.Repo,
  for_storing_parent_profiles:
    KlassHero.Family.Adapters.Driven.Persistence.Repositories.ParentProfileRepository,
  for_storing_children: KlassHero.Family.Adapters.Driven.Persistence.Repositories.ChildRepository,
  for_storing_consents:
    KlassHero.Family.Adapters.Driven.Persistence.Repositories.ConsentRepository,
  for_managing_child_enrollments:
    KlassHero.Family.Adapters.Driven.Enrollment.ChildEnrollmentACL,
  for_managing_child_participation:
    KlassHero.Family.Adapters.Driven.Participation.ChildParticipationACL
```

Note: `for_managing_child_participation` won't exist yet — that's fine, it'll be created in Task 2.

**Step 7: Commit**

```bash
git add lib/klass_hero/family/domain/ports/for_managing_child_enrollments.ex \
  lib/klass_hero/family/adapters/driven/acl/child_enrollment_acl.ex \
  test/klass_hero/family/adapters/driven/acl/child_enrollment_acl_test.exs \
  config/config.exs
git commit -m "feat(family): add enrollment cleanup ACL for child deletion (#298)"
```

---

### Task 2: Participation cleanup — port + ACL adapter

**Files:**
- Create: `lib/klass_hero/family/domain/ports/for_managing_child_participation.ex`
- Create: `lib/klass_hero/family/adapters/driven/participation/child_participation_acl.ex`
- Test: `test/klass_hero/family/adapters/driven/participation/child_participation_acl_test.exs`

**Step 1: Write the port behaviour**

```elixir
# lib/klass_hero/family/domain/ports/for_managing_child_participation.ex
defmodule KlassHero.Family.Domain.Ports.ForManagingChildParticipation do
  @moduledoc """
  Port for cleaning up participation data when deleting a child.

  Family needs to delete participation records and behavioral notes but
  cannot depend on the Participation context (which already depends on Family).
  This port is implemented by an ACL adapter that queries the tables directly.
  """

  @doc """
  Deletes all behavioral notes and participation records for a child.

  Behavioral notes are deleted first (they reference both child_id and
  participation_record_id). Then participation records are deleted.

  Returns count of deleted participation records.
  """
  @callback delete_all_for_child(child_id :: binary()) :: {:ok, non_neg_integer()}
end
```

**Step 2: Write the failing ACL adapter test**

```elixir
# test/klass_hero/family/adapters/driven/participation/child_participation_acl_test.exs
defmodule KlassHero.Family.Adapters.Driven.Participation.ChildParticipationACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Adapters.Driven.Participation.ChildParticipationACL
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema
  alias KlassHero.Repo

  import Ecto.Query

  describe "delete_all_for_child/1" do
    test "deletes participation records for a child" do
      record = insert(:participation_record_schema)

      assert {:ok, 1} = ChildParticipationACL.delete_all_for_child(record.child_id)

      assert [] = Repo.all(from(r in ParticipationRecordSchema, where: r.child_id == ^record.child_id))
    end

    test "deletes behavioral notes for a child before participation records" do
      record = insert(:participation_record_schema)

      insert(:behavioral_note_schema,
        participation_record_id: record.id,
        child_id: record.child_id,
        parent_id: record.parent_id
      )

      assert {:ok, 1} = ChildParticipationACL.delete_all_for_child(record.child_id)

      assert [] = Repo.all(from(n in BehavioralNoteSchema, where: n.child_id == ^record.child_id))
      assert [] = Repo.all(from(r in ParticipationRecordSchema, where: r.child_id == ^record.child_id))
    end

    test "returns zero count when no records exist" do
      {child, _parent} = insert_child_with_guardian()

      assert {:ok, 0} = ChildParticipationACL.delete_all_for_child(child.id)
    end

    test "does not delete records for other children" do
      record1 = insert(:participation_record_schema)
      record2 = insert(:participation_record_schema)

      assert {:ok, 1} = ChildParticipationACL.delete_all_for_child(record1.child_id)

      # Other child's record should still exist
      assert {:ok, _} =
               Repo.fetch(ParticipationRecordSchema, record2.id)
    end
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `mix test test/klass_hero/family/adapters/driven/participation/child_participation_acl_test.exs`
Expected: Compilation error — module `ChildParticipationACL` does not exist

**Step 4: Implement the ACL adapter**

```elixir
# lib/klass_hero/family/adapters/driven/participation/child_participation_acl.ex
defmodule KlassHero.Family.Adapters.Driven.Participation.ChildParticipationACL do
  @moduledoc """
  ACL adapter that cleans up participation data for child deletion.

  Deletes behavioral notes and participation records directly to avoid
  a dependency cycle (Participation already depends on Family).

  Behavioral notes must be deleted before participation records because
  behavioral_notes.child_id has an ON DELETE: nothing FK constraint that
  would block child deletion.
  """

  @behaviour KlassHero.Family.Domain.Ports.ForManagingChildParticipation

  import Ecto.Query, only: [from: 2]

  alias KlassHero.Repo

  @impl true
  def delete_all_for_child(child_id) when is_binary(child_id) do
    # Trigger: behavioral_notes.child_id has ON DELETE: nothing FK constraint
    # Why: must delete behavioral notes before participation records and before child
    # Outcome: no FK violations when participation records and child are deleted
    from(n in "behavioral_notes",
      where: n.child_id == type(^child_id, :binary_id)
    )
    |> Repo.delete_all()

    {count, _} =
      from(r in "participation_records",
        where: r.child_id == type(^child_id, :binary_id)
      )
      |> Repo.delete_all()

    {:ok, count}
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/family/adapters/driven/participation/child_participation_acl_test.exs`
Expected: All 4 tests pass

**Step 6: Commit**

```bash
git add lib/klass_hero/family/domain/ports/for_managing_child_participation.ex \
  lib/klass_hero/family/adapters/driven/participation/child_participation_acl.ex \
  test/klass_hero/family/adapters/driven/participation/child_participation_acl_test.exs
git commit -m "feat(family): add participation cleanup ACL for child deletion (#298)"
```

---

### Task 3: PrepareChildDeletion use case

**Files:**
- Create: `lib/klass_hero/family/application/use_cases/children/prepare_child_deletion.ex`
- Modify: `lib/klass_hero/family.ex:150` (add facade function + module attribute)
- Test: `test/klass_hero/family/application/use_cases/children/prepare_child_deletion_test.exs`

**Step 1: Write the failing test**

```elixir
# test/klass_hero/family/application/use_cases/children/prepare_child_deletion_test.exs
defmodule KlassHero.Family.Application.UseCases.Children.PrepareChildDeletionTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Application.UseCases.Children.PrepareChildDeletion

  describe "execute/1" do
    test "returns :no_enrollments when child has no active enrollments" do
      {child, _parent} = insert_child_with_guardian()

      assert {:ok, :no_enrollments} = PrepareChildDeletion.execute(child.id)
    end

    test "returns :has_enrollments with program titles when child has active enrollments" do
      program = insert(:program_schema, title: "Art Class")
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, :has_enrollments, program_titles} = PrepareChildDeletion.execute(child.id)
      assert "Art Class" in program_titles
    end

    test "returns multiple program titles for multiple enrollments" do
      program1 = insert(:program_schema, title: "Soccer Camp")
      program2 = insert(:program_schema, title: "Art Class")
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program1.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

      insert(:enrollment_schema,
        program_id: program2.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      assert {:ok, :has_enrollments, program_titles} = PrepareChildDeletion.execute(child.id)
      assert length(program_titles) == 2
      assert "Soccer Camp" in program_titles
      assert "Art Class" in program_titles
    end

    test "excludes cancelled enrollments" do
      program = insert(:program_schema, title: "Cancelled Program")
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "cancelled"
      )

      assert {:ok, :no_enrollments} = PrepareChildDeletion.execute(child.id)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/family/application/use_cases/children/prepare_child_deletion_test.exs`
Expected: Compilation error — module does not exist

**Step 3: Implement the use case**

```elixir
# lib/klass_hero/family/application/use_cases/children/prepare_child_deletion.ex
defmodule KlassHero.Family.Application.UseCases.Children.PrepareChildDeletion do
  @moduledoc """
  Use case for checking if a child can be safely deleted.

  Queries active enrollments to determine if a confirmation warning
  should be shown to the parent before deletion.
  """

  @enrollment_acl Application.compile_env!(:klass_hero, [
                    :family,
                    :for_managing_child_enrollments
                  ])

  @doc """
  Checks if a child has active enrollments.

  Returns:
  - `{:ok, :no_enrollments}` — safe to delete without warning
  - `{:ok, :has_enrollments, program_titles}` — show confirmation with program names
  """
  def execute(child_id) when is_binary(child_id) do
    case @enrollment_acl.list_active_with_program_titles(child_id) do
      [] ->
        {:ok, :no_enrollments}

      enrollments ->
        program_titles = Enum.map(enrollments, & &1.program_title)
        {:ok, :has_enrollments, program_titles}
    end
  end
end
```

**Step 4: Add facade function to Family module**

In `lib/klass_hero/family.ex`, add module attribute after line 59:

```elixir
@enrollment_acl Application.compile_env!(:klass_hero, [
                  :family,
                  :for_managing_child_enrollments
                ])
```

Add import for PrepareChildDeletion after the DeleteChild alias (line 35):

```elixir
alias KlassHero.Family.Application.UseCases.Children.PrepareChildDeletion
```

Add public function after `delete_child/1` (after line 152):

```elixir
@doc """
Checks if a child has active enrollments before deletion.

Returns:
- `{:ok, :no_enrollments}` — no active enrollments, safe to delete
- `{:ok, :has_enrollments, program_titles}` — child is enrolled in programs
"""
def prepare_child_deletion(child_id) when is_binary(child_id) do
  PrepareChildDeletion.execute(child_id)
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/family/application/use_cases/children/prepare_child_deletion_test.exs`
Expected: All 4 tests pass

**Step 6: Commit**

```bash
git add lib/klass_hero/family/application/use_cases/children/prepare_child_deletion.ex \
  lib/klass_hero/family.ex \
  test/klass_hero/family/application/use_cases/children/prepare_child_deletion_test.exs
git commit -m "feat(family): add PrepareChildDeletion use case (#298)"
```

---

### Task 4: Enhanced DeleteChild use case

**Files:**
- Modify: `lib/klass_hero/family/application/use_cases/children/delete_child.ex`
- Modify: `test/klass_hero/family/application/use_cases/children/delete_child_test.exs`

**Step 1: Write the new failing tests**

Add to the existing test file `test/klass_hero/family/application/use_cases/children/delete_child_test.exs`:

```elixir
# Add these aliases at the top (after existing aliases):
alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema

# Add these tests in the "execute/1" describe block:

test "deletes child with active enrollments (cancels enrollments)" do
  program = insert(:program_schema)
  {child, parent} = insert_child_with_guardian()

  enrollment =
    insert(:enrollment_schema,
      program_id: program.id,
      child_id: child.id,
      parent_id: parent.id,
      status: "confirmed"
    )

  assert :ok = DeleteChild.execute(child.id)

  # Enrollment should be cancelled, not deleted
  updated = Repo.get(EnrollmentSchema, enrollment.id)
  assert updated.status == "cancelled"
end

test "deletes child with participation records" do
  {child, parent} = insert_child_with_guardian()
  session = insert(:program_session_schema)

  insert(:participation_record_schema,
    child_id: child.id,
    parent_id: parent.id,
    session_id: session.id
  )

  assert :ok = DeleteChild.execute(child.id)

  assert [] = Repo.all(from(r in ParticipationRecordSchema, where: r.child_id == ^child.id))
end

test "deletes child with behavioral notes and participation records" do
  {child, parent} = insert_child_with_guardian()
  record = insert(:participation_record_schema, child_id: child.id, parent_id: parent.id)

  insert(:behavioral_note_schema,
    participation_record_id: record.id,
    child_id: child.id,
    parent_id: parent.id
  )

  assert :ok = DeleteChild.execute(child.id)

  assert [] = Repo.all(from(n in BehavioralNoteSchema, where: n.child_id == ^child.id))
  assert [] = Repo.all(from(r in ParticipationRecordSchema, where: r.child_id == ^child.id))
end

test "deletes child with enrollments, participation records, and consents" do
  program = insert(:program_schema)
  {child, parent} = insert_child_with_guardian()
  session = insert(:program_session_schema)

  insert(:enrollment_schema,
    program_id: program.id,
    child_id: child.id,
    parent_id: parent.id,
    status: "pending"
  )

  insert(:participation_record_schema,
    child_id: child.id,
    parent_id: parent.id,
    session_id: session.id
  )

  insert(:consent_schema,
    child_id: child.id,
    parent_id: parent.id
  )

  assert :ok = DeleteChild.execute(child.id)
end
```

**Step 2: Run tests to verify the new ones fail**

Run: `mix test test/klass_hero/family/application/use_cases/children/delete_child_test.exs`
Expected: New tests fail with FK constraint violation errors; existing tests still pass

**Step 3: Update the DeleteChild use case**

Replace the contents of `lib/klass_hero/family/application/use_cases/children/delete_child.ex`:

```elixir
defmodule KlassHero.Family.Application.UseCases.Children.DeleteChild do
  @moduledoc """
  Use case for deleting a child and all associated records.

  Cleans up cross-context data (enrollments, participation records) via
  ACL adapters, then deletes Family-owned data (consents, child) within
  a single transaction.
  """

  @repo Application.compile_env!(:klass_hero, [:family, :repo])
  @child_repo Application.compile_env!(:klass_hero, [:family, :for_storing_children])
  @consent_repo Application.compile_env!(:klass_hero, [:family, :for_storing_consents])
  @enrollment_acl Application.compile_env!(:klass_hero, [
                    :family,
                    :for_managing_child_enrollments
                  ])
  @participation_acl Application.compile_env!(:klass_hero, [
                       :family,
                       :for_managing_child_participation
                     ])

  @doc """
  Deletes a child and all associated records across contexts.

  Transaction order (satisfies FK RESTRICT constraints):
  1. Delete consents (Family-owned, FK RESTRICT on child_id)
  2. Cancel active enrollments (cross-context via ACL)
  3. Delete behavioral notes + participation records (cross-context via ACL)
  4. Delete child (FK cascade handles children_guardians)

  Returns:
  - `:ok` on success
  - `{:error, :not_found}` if child doesn't exist
  """
  def execute(child_id) when is_binary(child_id) do
    @repo.transaction(fn ->
      # Trigger: consents have FK RESTRICT constraint on child_id
      # Why: must delete consents before the child or PostgreSQL rejects the delete
      # Outcome: consent records removed
      {:ok, _count} = @consent_repo.delete_all_for_child(child_id)

      # Trigger: enrollments have FK RESTRICT constraint on child_id
      # Why: cancelling (not deleting) preserves audit trail for providers
      # Outcome: active enrollments set to "cancelled" status
      {:ok, _count} = @enrollment_acl.cancel_active_for_child(child_id)

      # Trigger: behavioral_notes.child_id has ON DELETE: nothing, participation_records has FK RESTRICT
      # Why: ACL deletes behavioral notes first, then participation records
      # Outcome: all participation data for this child removed
      {:ok, _count} = @participation_acl.delete_all_for_child(child_id)

      case @child_repo.delete(child_id) do
        :ok -> :ok
        {:error, reason} -> @repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**Step 4: Run all tests to verify they pass**

Run: `mix test test/klass_hero/family/application/use_cases/children/delete_child_test.exs`
Expected: All tests pass (existing + new)

**Step 5: Commit**

```bash
git add lib/klass_hero/family/application/use_cases/children/delete_child.ex \
  test/klass_hero/family/application/use_cases/children/delete_child_test.exs
git commit -m "feat(family): handle cross-context cleanup in DeleteChild (#298)"
```

---

### Task 5: LiveView — two-step delete flow

**Files:**
- Modify: `lib/klass_hero_web/live/settings/children_live.ex`
- Modify: `test/klass_hero_web/live/settings/children_live_test.exs`

**Step 1: Write the failing LiveView tests**

Update the `"delete child"` describe block in `test/klass_hero_web/live/settings/children_live_test.exs`.

Replace the existing `"clicking delete removes child from list"` test and add new tests:

```elixir
describe "delete child" do
  setup :register_and_log_in_user_with_child

  test "deleting child with no enrollments removes child immediately", %{
    conn: conn,
    child: child
  } do
    {:ok, view, _html} = live(conn, ~p"/settings/children")

    view
    |> element("button[phx-click='request_delete_child'][phx-value-id='#{child.id}']")
    |> render_click()

    # No enrollments — child deleted immediately
    refute render(view) =~ child.first_name
    assert {:error, :not_found} = Family.get_child_by_id(child.id)
  end

  test "deleting child with active enrollments shows confirmation modal", %{
    conn: conn,
    child: child,
    parent: parent
  } do
    program = KlassHero.Factory.insert(:program_schema, title: "Soccer Camp")

    KlassHero.Factory.insert(:enrollment_schema,
      program_id: program.id,
      child_id: child.id,
      parent_id: parent.id,
      status: "confirmed"
    )

    {:ok, view, _html} = live(conn, ~p"/settings/children")

    view
    |> element("button[phx-click='request_delete_child'][phx-value-id='#{child.id}']")
    |> render_click()

    # Should show confirmation modal with program name
    html = render(view)
    assert html =~ "Soccer Camp"
    assert has_element?(view, "#delete-confirmation-modal")

    # Child should still exist
    assert {:ok, _} = Family.get_child_by_id(child.id)
  end

  test "confirming deletion in modal deletes child and cancels enrollments", %{
    conn: conn,
    child: child,
    parent: parent
  } do
    program = KlassHero.Factory.insert(:program_schema, title: "Art Class")

    enrollment =
      KlassHero.Factory.insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "confirmed"
      )

    {:ok, view, _html} = live(conn, ~p"/settings/children")

    # Request delete — shows modal
    view
    |> element("button[phx-click='request_delete_child'][phx-value-id='#{child.id}']")
    |> render_click()

    # Confirm deletion
    view
    |> element("#confirm-delete-btn")
    |> render_click()

    refute render(view) =~ child.first_name
    assert {:error, :not_found} = Family.get_child_by_id(child.id)

    # Enrollment should be cancelled
    updated = KlassHero.Repo.get(
      KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema,
      enrollment.id
    )
    assert updated.status == "cancelled"
  end

  test "cancelling the confirmation modal does not delete child", %{
    conn: conn,
    child: child,
    parent: parent
  } do
    program = KlassHero.Factory.insert(:program_schema)

    KlassHero.Factory.insert(:enrollment_schema,
      program_id: program.id,
      child_id: child.id,
      parent_id: parent.id,
      status: "confirmed"
    )

    {:ok, view, _html} = live(conn, ~p"/settings/children")

    view
    |> element("button[phx-click='request_delete_child'][phx-value-id='#{child.id}']")
    |> render_click()

    # Cancel — dismiss modal
    view
    |> element("#cancel-delete-btn")
    |> render_click()

    refute has_element?(view, "#delete-confirmation-modal")
    assert {:ok, _} = Family.get_child_by_id(child.id)
  end

  test "cannot delete child belonging to another parent", %{conn: conn} do
    other_parent = KlassHero.Factory.insert(:parent_schema)

    {other_child, _other_parent} =
      KlassHero.Factory.insert_child_with_guardian(parent: other_parent)

    {:ok, view, _html} = live(conn, ~p"/settings/children")

    render_click(view, "request_delete_child", %{"id" => other_child.id})

    assert {:ok, _} = Family.get_child_by_id(other_child.id)
  end
end
```

**Step 2: Run tests to verify the new ones fail**

Run: `mix test test/klass_hero_web/live/settings/children_live_test.exs`
Expected: Tests fail — `request_delete_child` event not handled, no confirmation modal elements

**Step 3: Update ChildrenLive — event handlers**

In `lib/klass_hero_web/live/settings/children_live.ex`, replace the `handle_event("delete_child", ...)` (lines 117-144) with:

```elixir
def handle_event("request_delete_child", %{"id" => child_id}, socket) do
  # Trigger: verify child belongs to current parent before proceeding
  # Why: prevent unauthorized deletion
  # Outcome: only proceed if ownership confirmed
  if Family.child_belongs_to_parent?(child_id, socket.assigns.parent_id) do
    case Family.prepare_child_deletion(child_id) do
      {:ok, :no_enrollments} ->
        do_delete_child(socket, child_id)

      {:ok, :has_enrollments, program_titles} ->
        {:noreply,
         socket
         |> assign(delete_candidate: child_id)
         |> assign(enrolled_programs: program_titles)}
    end
  else
    {:noreply,
     put_flash(socket, :error, gettext("You don't have permission to delete this child."))}
  end
end

def handle_event("confirm_delete_child", _params, socket) do
  child_id = socket.assigns.delete_candidate
  do_delete_child(socket, child_id)
end

def handle_event("cancel_delete", _params, socket) do
  {:noreply,
   socket
   |> assign(delete_candidate: nil)
   |> assign(enrolled_programs: [])}
end

defp do_delete_child(socket, child_id) do
  case Family.delete_child(child_id) do
    :ok ->
      new_count = socket.assigns.children_count - 1

      {:noreply,
       socket
       |> stream_delete_by_dom_id(:children, "children-#{child_id}")
       |> assign(children_count: new_count)
       |> assign(children_empty?: new_count == 0)
       |> assign(delete_candidate: nil)
       |> assign(enrolled_programs: [])
       |> put_flash(:info, gettext("Child removed successfully."))}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, gettext("Child not found."))}

    {:error, _reason} ->
      {:noreply,
       put_flash(socket, :error, gettext("Could not remove child. Please try again."))}
  end
end
```

**Step 4: Update mount to initialize new assigns**

In `mount/3`, add to the socket pipeline (after the `children_empty?` assign, around line 26):

```elixir
|> assign(delete_candidate: nil)
|> assign(enrolled_programs: [])
```

**Step 5: Update the template — delete button + confirmation modal**

In the `render/1` function, change the delete button (around line 421-435) from:

```heex
<button
  type="button"
  phx-click="delete_child"
  phx-value-id={child.id}
  data-confirm={gettext("Are you sure you want to remove this child?")}
  ...
```

To:

```heex
<button
  type="button"
  phx-click="request_delete_child"
  phx-value-id={child.id}
  ...
```

(Remove the `data-confirm` attribute.)

Add the confirmation modal at the end of the template, just before the closing `</div>` of the outermost div (before the add/edit modal):

```heex
<%!-- Delete Confirmation Modal --%>
<%= if @delete_candidate do %>
  <div
    id="delete-modal-backdrop"
    class="fixed inset-0 z-50 bg-black/50"
    phx-click="cancel_delete"
  >
  </div>
  <div
    id="delete-confirmation-modal"
    class={[
      "fixed inset-x-4 top-[20%] z-50 mx-auto max-w-md",
      Theme.bg(:surface),
      Theme.rounded(:xl),
      "shadow-xl p-6"
    ]}
    phx-click-away="cancel_delete"
  >
    <div class="flex items-center gap-3 mb-4">
      <div class="flex-shrink-0 w-10 h-10 rounded-full bg-red-100 flex items-center justify-center">
        <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-red-600" />
      </div>
      <h3 class={["text-lg font-semibold", Theme.text_color(:heading)]}>
        {gettext("Remove Child?")}
      </h3>
    </div>

    <p class={["text-sm mb-3", Theme.text_color(:body)]}>
      {gettext("This child is currently enrolled in the following programs:")}
    </p>

    <ul class="mb-4 space-y-1">
      <%= for title <- @enrolled_programs do %>
        <li class="flex items-center gap-2 text-sm text-hero-grey-700">
          <.icon name="hero-academic-cap-mini" class="w-4 h-4 text-hero-blue-500" />
          {title}
        </li>
      <% end %>
    </ul>

    <p class={["text-sm mb-4", Theme.text_color(:muted)]}>
      {gettext("Their enrollments will be cancelled. This action cannot be undone.")}
    </p>

    <div class="flex justify-end gap-3">
      <button
        type="button"
        id="cancel-delete-btn"
        phx-click="cancel_delete"
        class={[
          "px-4 py-2 text-sm font-medium text-hero-grey-700",
          "bg-hero-grey-100 hover:bg-hero-grey-200",
          Theme.rounded(:lg),
          Theme.transition(:normal)
        ]}
      >
        {gettext("Cancel")}
      </button>
      <button
        type="button"
        id="confirm-delete-btn"
        phx-click="confirm_delete_child"
        class={[
          "px-4 py-2 text-sm font-semibold text-white",
          "bg-red-600 hover:bg-red-700",
          Theme.rounded(:lg),
          Theme.transition(:normal)
        ]}
      >
        {gettext("Remove Child")}
      </button>
    </div>
  </div>
<% end %>
```

**Step 6: Run all tests to verify they pass**

Run: `mix test test/klass_hero_web/live/settings/children_live_test.exs`
Expected: All tests pass

**Step 7: Run full precommit checks**

Run: `mix precommit`
Expected: Zero warnings, all tests pass

**Step 8: Commit**

```bash
git add lib/klass_hero_web/live/settings/children_live.ex \
  test/klass_hero_web/live/settings/children_live_test.exs
git commit -m "feat(liveview): two-step child deletion with enrollment warning (#298)"
```

---

### Task 6: Final verification + gettext extraction

**Step 1: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 2: Extract gettext strings**

Run: `mix gettext.extract`

Check if any new `.pot` entries were added for the confirmation modal strings.

**Step 3: Run precommit**

Run: `mix precommit`
Expected: Clean — zero warnings, all tests pass

**Step 4: Commit gettext changes (if any)**

```bash
git add priv/gettext/
git commit -m "chore: extract gettext strings for child deletion modal (#298)"
```
