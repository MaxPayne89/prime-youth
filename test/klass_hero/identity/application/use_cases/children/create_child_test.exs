defmodule KlassHero.Identity.Application.UseCases.Children.CreateChildTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Identity.Application.UseCases.Children.CreateChild
  alias KlassHero.Identity.Domain.Models.Child

  describe "execute/1" do
    test "creates child with valid params" do
      parent = insert(:parent_profile_schema)

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:ok, %Child{} = child} = CreateChild.execute(attrs)
      assert child.parent_id == parent.id
      assert child.first_name == "Emma"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2015-06-15]
    end

    test "generates UUID when not provided" do
      parent = insert(:parent_profile_schema)

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      {:ok, child} = CreateChild.execute(attrs)

      assert is_binary(child.id)
      assert byte_size(child.id) == 36
    end

    test "returns validation error for future date_of_birth" do
      parent = insert(:parent_profile_schema)
      future_date = Date.add(Date.utc_today(), 30)

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: future_date
      }

      assert {:error, {:validation_error, errors}} = CreateChild.execute(attrs)
      assert is_list(errors)
    end

    test "returns validation error for empty first_name" do
      parent = insert(:parent_profile_schema)

      attrs = %{
        parent_id: parent.id,
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, {:validation_error, errors}} = CreateChild.execute(attrs)
      assert is_list(errors)
    end
  end
end
