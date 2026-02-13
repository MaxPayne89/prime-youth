defmodule KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema

  describe "form_changeset/2" do
    test "excludes parent_id from cast" do
      changeset =
        ChildSchema.form_changeset(%ChildSchema{}, %{
          parent_id: Ecto.UUID.generate(),
          first_name: "Alice",
          last_name: "Wonder",
          date_of_birth: ~D[2017-03-15]
        })

      refute Ecto.Changeset.get_change(changeset, :parent_id)
    end

    test "validates required fields" do
      changeset =
        %ChildSchema{}
        |> ChildSchema.form_changeset(%{})
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert errors_on(changeset).first_name
      assert errors_on(changeset).last_name
      assert errors_on(changeset).date_of_birth
    end

    test "validates first_name and last_name length bounds" do
      long_name = String.duplicate("a", 101)

      changeset =
        %ChildSchema{}
        |> ChildSchema.form_changeset(%{
          first_name: long_name,
          last_name: long_name,
          date_of_birth: ~D[2017-03-15]
        })
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).first_name
      assert "should be at most 100 character(s)" in errors_on(changeset).last_name
    end

    test "validates date_of_birth is in the past" do
      future_date = Date.add(Date.utc_today(), 1)

      changeset =
        %ChildSchema{}
        |> ChildSchema.form_changeset(%{
          first_name: "Alice",
          last_name: "Wonder",
          date_of_birth: future_date
        })
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "must be in the past" in errors_on(changeset).date_of_birth
    end

    test "validates emergency_contact max length" do
      long_contact = String.duplicate("x", 256)

      changeset =
        %ChildSchema{}
        |> ChildSchema.form_changeset(%{
          first_name: "Alice",
          last_name: "Wonder",
          date_of_birth: ~D[2017-03-15],
          emergency_contact: long_contact
        })
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).emergency_contact
    end

    test "accepts valid attributes" do
      changeset =
        ChildSchema.form_changeset(%ChildSchema{}, %{
          first_name: "Alice",
          last_name: "Wonder",
          date_of_birth: ~D[2017-03-15],
          emergency_contact: "+49 123 456",
          allergies: "Peanuts",
          support_needs: "None"
        })

      assert changeset.valid?
    end
  end
end
