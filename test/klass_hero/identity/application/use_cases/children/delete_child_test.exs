defmodule KlassHero.Identity.Application.UseCases.Children.DeleteChildTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Identity.Application.UseCases.Children.DeleteChild

  describe "execute/1" do
    test "deletes existing child" do
      child_schema = insert(:child_schema)

      assert :ok = DeleteChild.execute(child_schema.id)
    end

    test "returns :not_found for non-existent child" do
      assert {:error, :not_found} = DeleteChild.execute(Ecto.UUID.generate())
    end
  end
end
