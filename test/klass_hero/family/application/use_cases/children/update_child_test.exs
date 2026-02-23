defmodule KlassHero.Family.Application.UseCases.Children.UpdateChildTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Application.UseCases.Children.UpdateChild
  alias KlassHero.Family.Domain.Models.Child

  defp create_persisted_child do
    child_schema = insert(:child_schema)

    %{
      id: child_schema.id,
      first_name: child_schema.first_name,
      last_name: child_schema.last_name,
      date_of_birth: child_schema.date_of_birth
    }
  end

  describe "execute/2" do
    test "updates child with valid params" do
      child_data = create_persisted_child()

      assert {:ok, %Child{} = updated} =
               UpdateChild.execute(child_data.id, %{first_name: "UpdatedName"})

      assert updated.first_name == "UpdatedName"
      assert updated.id == child_data.id
    end

    test "updates optional fields" do
      child_data = create_persisted_child()

      assert {:ok, %Child{} = updated} =
               UpdateChild.execute(child_data.id, %{
                 allergies: "Peanuts",
                 emergency_contact: "555-9999"
               })

      assert updated.allergies == "Peanuts"
      assert updated.emergency_contact == "555-9999"
    end

    test "returns :not_found for non-existent child" do
      assert {:error, :not_found} =
               UpdateChild.execute(Ecto.UUID.generate(), %{first_name: "X"})
    end

    test "returns validation error for empty first_name" do
      child_data = create_persisted_child()

      assert {:error, {:validation_error, errors}} =
               UpdateChild.execute(child_data.id, %{first_name: ""})

      assert is_list(errors)
    end
  end
end
