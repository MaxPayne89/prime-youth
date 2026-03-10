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
