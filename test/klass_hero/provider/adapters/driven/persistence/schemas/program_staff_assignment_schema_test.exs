defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema

  describe "create_changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{
        provider_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        staff_member_id: Ecto.UUID.generate(),
        assigned_at: DateTime.utc_now()
      }

      changeset = ProgramStaffAssignmentSchema.create_changeset(attrs)
      assert changeset.valid?
    end

    test "missing required fields produce invalid changeset" do
      changeset = ProgramStaffAssignmentSchema.create_changeset(%{})
      refute changeset.valid?

      assert %{provider_id: _, program_id: _, staff_member_id: _, assigned_at: _} =
               errors_on(changeset)
    end
  end

  describe "unassign_changeset/1" do
    test "sets unassigned_at to current time" do
      schema = %ProgramStaffAssignmentSchema{
        id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        staff_member_id: Ecto.UUID.generate(),
        assigned_at: DateTime.utc_now()
      }

      changeset = ProgramStaffAssignmentSchema.unassign_changeset(schema)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :unassigned_at) != nil
    end
  end
end
