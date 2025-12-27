defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Mappers.ParentMapperTest do
  @moduledoc """
  Tests for the ParentMapper adapter.

  Tests bidirectional conversion between ParentSchema and Parent domain entity.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Mappers.ParentMapper
  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema
  alias PrimeYouth.Parenting.Domain.Models.Parent

  # =============================================================================
  # to_domain/1
  # =============================================================================

  describe "to_domain/1" do
    test "maps all fields from schema to domain entity" do
      now = ~U[2025-01-15 10:30:00Z]

      schema = %ParentSchema{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false},
        inserted_at: now,
        updated_at: now
      }

      parent = ParentMapper.to_domain(schema)

      assert %Parent{} = parent
      assert parent.id == "550e8400-e29b-41d4-a716-446655440000"
      assert parent.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert parent.display_name == "John Doe"
      assert parent.phone == "+1234567890"
      assert parent.location == "New York, NY"
      assert parent.notification_preferences == %{email: true, sms: false}
      assert parent.inserted_at == now
      assert parent.updated_at == now
    end

    test "converts UUID binary to string for id" do
      uuid = Ecto.UUID.generate()

      schema = %ParentSchema{
        id: uuid,
        identity_id: Ecto.UUID.generate(),
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      parent = ParentMapper.to_domain(schema)

      assert is_binary(parent.id)
      assert parent.id == uuid
    end

    test "converts UUID binary to string for identity_id" do
      uuid = Ecto.UUID.generate()

      schema = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: uuid,
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      parent = ParentMapper.to_domain(schema)

      assert is_binary(parent.identity_id)
      assert parent.identity_id == uuid
    end

    test "preserves nil values for optional fields" do
      schema = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      parent = ParentMapper.to_domain(schema)

      assert is_nil(parent.display_name)
      assert is_nil(parent.phone)
      assert is_nil(parent.location)
      assert is_nil(parent.notification_preferences)
      assert is_nil(parent.inserted_at)
      assert is_nil(parent.updated_at)
    end

    test "preserves timestamps through mapping" do
      inserted = ~U[2025-01-10 08:00:00Z]
      updated = ~U[2025-01-15 14:30:00Z]

      schema = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: "Test",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: inserted,
        updated_at: updated
      }

      parent = ParentMapper.to_domain(schema)

      assert parent.inserted_at == inserted
      assert parent.updated_at == updated
    end
  end

  # =============================================================================
  # from_domain/1
  # =============================================================================

  describe "to_schema/1" do
    test "maps all fields from domain entity to attrs map" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true},
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      attrs = ParentMapper.to_schema(parent)

      assert is_map(attrs)
      assert attrs.id == "550e8400-e29b-41d4-a716-446655440000"
      assert attrs.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert attrs.display_name == "John Doe"
      assert attrs.phone == "+1234567890"
      assert attrs.location == "New York, NY"
      assert attrs.notification_preferences == %{email: true}
    end

    test "excludes id when nil (allows Ecto to auto-generate)" do
      parent = %Parent{
        id: nil,
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ParentMapper.to_schema(parent)

      refute Map.has_key?(attrs, :id)
      assert attrs.identity_id == "660e8400-e29b-41d4-a716-446655440001"
    end

    test "includes id when present" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ParentMapper.to_schema(parent)

      assert Map.has_key?(attrs, :id)
      assert attrs.id == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "preserves nil values for optional fields" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ParentMapper.to_schema(parent)

      assert is_nil(attrs.display_name)
      assert is_nil(attrs.phone)
      assert is_nil(attrs.location)
      assert is_nil(attrs.notification_preferences)
    end

    test "does not include timestamps in attrs (Ecto manages them)" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: nil,
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      attrs = ParentMapper.to_schema(parent)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end
  end

  # =============================================================================
  # to_domain_list/1
  # =============================================================================

  describe "to_domain_list/1" do
    test "returns empty list for empty input" do
      result = ParentMapper.to_domain_list([])

      assert result == []
    end

    test "maps single schema to list with one domain entity" do
      schema = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: "Single Parent",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      result = ParentMapper.to_domain_list([schema])

      assert length(result) == 1
      assert [%Parent{display_name: "Single Parent"}] = result
    end

    test "maps multiple schemas to list of domain entities" do
      schema1 = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: "Parent One",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      schema2 = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: "Parent Two",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      schema3 = %ParentSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        display_name: "Parent Three",
        phone: nil,
        location: nil,
        notification_preferences: nil,
        inserted_at: nil,
        updated_at: nil
      }

      result = ParentMapper.to_domain_list([schema1, schema2, schema3])

      assert length(result) == 3
      assert Enum.all?(result, &match?(%Parent{}, &1))

      display_names = Enum.map(result, & &1.display_name)
      assert "Parent One" in display_names
      assert "Parent Two" in display_names
      assert "Parent Three" in display_names
    end

    test "preserves order of schemas" do
      schemas =
        Enum.map(1..5, fn i ->
          %ParentSchema{
            id: Ecto.UUID.generate(),
            identity_id: Ecto.UUID.generate(),
            display_name: "Parent #{i}",
            phone: nil,
            location: nil,
            notification_preferences: nil,
            inserted_at: nil,
            updated_at: nil
          }
        end)

      result = ParentMapper.to_domain_list(schemas)

      expected_names = Enum.map(1..5, &"Parent #{&1}")
      actual_names = Enum.map(result, & &1.display_name)

      assert actual_names == expected_names
    end
  end
end
