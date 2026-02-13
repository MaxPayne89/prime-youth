defmodule KlassHero.Family.Adapters.Driven.Persistence.Mappers.ChildMapperTest do
  @moduledoc """
  Tests for ChildMapper, focusing on conversion and error handling.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Mappers.ChildMapper
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema

  describe "to_domain/1" do
    test "converts a valid schema to a domain entity" do
      schema = %ChildSchema{
        id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: "555-1234",
        support_needs: nil,
        allergies: "Peanuts",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      child = ChildMapper.to_domain(schema)

      assert child.first_name == "Emma"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2015-06-15]
      assert child.allergies == "Peanuts"
      assert child.support_needs == nil
    end
  end
end
