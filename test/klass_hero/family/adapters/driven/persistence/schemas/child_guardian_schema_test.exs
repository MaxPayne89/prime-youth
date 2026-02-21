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
