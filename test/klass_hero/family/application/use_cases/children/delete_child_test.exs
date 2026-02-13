defmodule KlassHero.Family.Application.UseCases.Children.DeleteChildTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Family.Application.UseCases.Children.DeleteChild
  alias KlassHero.Repo

  describe "execute/1" do
    test "deletes existing child" do
      child_schema = insert(:child_schema)

      assert :ok = DeleteChild.execute(child_schema.id)
    end

    test "deletes child with associated consent records" do
      child_schema = insert(:child_schema)

      insert(:consent_schema,
        child_id: child_schema.id,
        parent_id: child_schema.parent_id
      )

      assert :ok = DeleteChild.execute(child_schema.id)

      # Verify consent records are also deleted
      assert Repo.all(from(c in ConsentSchema, where: c.child_id == ^child_schema.id)) == []
    end

    test "returns :not_found for non-existent child" do
      assert {:error, :not_found} = DeleteChild.execute(Ecto.UUID.generate())
    end
  end
end
