defmodule KlassHero.Family.Adapters.Driven.Persistence.Mappers.ParentProfileMapperTest do
  @moduledoc """
  Unit tests for ParentProfileMapper.

  Tests round-trip mapping between ParentProfileSchema and ParentProfile domain entities.
  No database required — schemas and domain structs are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Mappers.ParentProfileMapper
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Family.Domain.Models.ParentProfile

  @identity_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      identity_id: @identity_id,
      display_name: "Anna Klein",
      phone: "+49 176 1234 5678",
      location: "Munich, DE",
      notification_preferences: %{"email" => true, "push" => false},
      subscription_tier: "explorer",
      inserted_at: ~U[2025-06-15 08:00:00Z],
      updated_at: ~U[2025-06-15 08:00:00Z]
    }

    struct!(ParentProfileSchema, Map.merge(defaults, overrides))
  end

  defp valid_domain(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      identity_id: @identity_id,
      display_name: "Anna Klein",
      phone: "+49 176 1234 5678",
      location: "Munich, DE",
      notification_preferences: %{"email" => true},
      subscription_tier: :explorer,
      inserted_at: ~U[2025-06-15 08:00:00Z],
      updated_at: ~U[2025-06-15 08:00:00Z]
    }

    struct!(ParentProfile, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "converts a valid schema to a ParentProfile domain entity" do
      schema = valid_schema()

      parent = ParentProfileMapper.to_domain(schema)

      assert %ParentProfile{} = parent
      assert parent.display_name == "Anna Klein"
      assert parent.phone == "+49 176 1234 5678"
      assert parent.location == "Munich, DE"
      assert parent.notification_preferences == %{"email" => true, "push" => false}
    end

    test "converts subscription_tier string to atom" do
      explorer_schema = valid_schema(%{subscription_tier: "explorer"})
      active_schema = valid_schema(%{subscription_tier: "active"})

      assert ParentProfileMapper.to_domain(explorer_schema).subscription_tier == :explorer
      assert ParentProfileMapper.to_domain(active_schema).subscription_tier == :active
    end

    test "uses :explorer as default when subscription_tier is nil" do
      schema = valid_schema(%{subscription_tier: nil})

      parent = ParentProfileMapper.to_domain(schema)

      assert parent.subscription_tier == :explorer
    end

    test "preserves id and identity_id as strings" do
      schema = valid_schema()

      parent = ParentProfileMapper.to_domain(schema)

      assert parent.id == schema.id
      assert parent.identity_id == schema.identity_id
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      parent = ParentProfileMapper.to_domain(schema)

      assert parent.inserted_at == ~U[2025-06-15 08:00:00Z]
      assert parent.updated_at == ~U[2025-06-15 08:00:00Z]
    end

    test "handles nil optional fields" do
      schema = valid_schema(%{display_name: nil, phone: nil, location: nil})

      parent = ParentProfileMapper.to_domain(schema)

      assert parent.display_name == nil
      assert parent.phone == nil
      assert parent.location == nil
    end
  end

  describe "to_schema/1" do
    test "converts a domain entity to schema attrs map" do
      domain = valid_domain()

      attrs = ParentProfileMapper.to_schema(domain)

      assert is_map(attrs)
      assert attrs.identity_id == @identity_id
      assert attrs.display_name == "Anna Klein"
      assert attrs.phone == "+49 176 1234 5678"
      assert attrs.location == "Munich, DE"
    end

    test "converts subscription_tier atom to string" do
      explorer_domain = valid_domain(%{subscription_tier: :explorer})
      active_domain = valid_domain(%{subscription_tier: :active})

      assert ParentProfileMapper.to_schema(explorer_domain).subscription_tier == "explorer"
      assert ParentProfileMapper.to_schema(active_domain).subscription_tier == "active"
    end

    test "uses 'explorer' string when subscription_tier is nil" do
      domain = valid_domain(%{subscription_tier: nil})

      attrs = ParentProfileMapper.to_schema(domain)

      assert attrs.subscription_tier == "explorer"
    end

    test "excludes database-managed timestamps from schema attrs" do
      domain = valid_domain()

      attrs = ParentProfileMapper.to_schema(domain)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end

    test "includes id when domain entity has an id" do
      id = Ecto.UUID.generate()
      domain = valid_domain(%{id: id})

      attrs = ParentProfileMapper.to_schema(domain)

      assert attrs.id == id
    end

    test "excludes id when domain entity has nil id" do
      domain = valid_domain(%{id: nil})

      attrs = ParentProfileMapper.to_schema(domain)

      refute Map.has_key?(attrs, :id)
    end
  end
end
