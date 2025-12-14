defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Mappers.ProviderMapperTest do
  @moduledoc """
  Tests for the ProviderMapper adapter.

  Tests bidirectional conversion between ProviderSchema and Provider domain entity.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Mappers.ProviderMapper
  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema
  alias PrimeYouth.Providing.Domain.Models.Provider

  # =============================================================================
  # to_domain/1
  # =============================================================================

  describe "to_domain/1" do
    test "maps all fields from schema to domain entity" do
      now = ~U[2025-01-15 10:30:00Z]
      verified_at = ~U[2025-01-10 08:00:00Z]

      schema = %ProviderSchema{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane, Athletic City",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: true,
        verified_at: verified_at,
        categories: ["sports", "outdoor"],
        inserted_at: now,
        updated_at: now
      }

      provider = ProviderMapper.to_domain(schema)

      assert %Provider{} = provider
      assert provider.id == "550e8400-e29b-41d4-a716-446655440000"
      assert provider.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert provider.business_name == "Kids Sports Academy"
      assert provider.description == "Premier youth sports training"
      assert provider.phone == "+1234567890"
      assert provider.website == "https://kidssports.example.com"
      assert provider.address == "123 Sports Lane, Athletic City"
      assert provider.logo_url == "https://kidssports.example.com/logo.png"
      assert provider.verified == true
      assert provider.verified_at == verified_at
      assert provider.categories == ["sports", "outdoor"]
      assert provider.inserted_at == now
      assert provider.updated_at == now
    end

    test "converts UUID binary to string for id" do
      uuid = Ecto.UUID.generate()

      schema = %ProviderSchema{
        id: uuid,
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert is_binary(provider.id)
      assert provider.id == uuid
    end

    test "converts UUID binary to string for identity_id" do
      uuid = Ecto.UUID.generate()

      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: uuid,
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert is_binary(provider.identity_id)
      assert provider.identity_id == uuid
    end

    test "preserves nil values for optional fields" do
      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert is_nil(provider.description)
      assert is_nil(provider.phone)
      assert is_nil(provider.website)
      assert is_nil(provider.address)
      assert is_nil(provider.logo_url)
      assert is_nil(provider.verified_at)
      assert is_nil(provider.inserted_at)
      assert is_nil(provider.updated_at)
    end

    test "preserves timestamps through mapping" do
      inserted = ~U[2025-01-10 08:00:00Z]
      updated = ~U[2025-01-15 14:30:00Z]

      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: inserted,
        updated_at: updated
      }

      provider = ProviderMapper.to_domain(schema)

      assert provider.inserted_at == inserted
      assert provider.updated_at == updated
    end

    test "preserves verified and verified_at independently" do
      verified_at = ~U[2025-01-10 08:00:00Z]

      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: verified_at,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert provider.verified == false
      assert provider.verified_at == verified_at
    end

    test "preserves empty categories list" do
      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert provider.categories == []
    end

    test "preserves categories list with multiple items" do
      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: ["sports", "outdoor", "youth"],
        inserted_at: nil,
        updated_at: nil
      }

      provider = ProviderMapper.to_domain(schema)

      assert provider.categories == ["sports", "outdoor", "youth"]
    end
  end

  # =============================================================================
  # from_domain/1
  # =============================================================================

  describe "from_domain/1" do
    test "maps all fields from domain entity to attrs map" do
      verified_at = ~U[2025-01-10 08:00:00Z]

      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: true,
        verified_at: verified_at,
        categories: ["sports", "outdoor"],
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      attrs = ProviderMapper.from_domain(provider)

      assert is_map(attrs)
      assert attrs.id == "550e8400-e29b-41d4-a716-446655440000"
      assert attrs.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert attrs.business_name == "Kids Sports Academy"
      assert attrs.description == "Premier youth sports training"
      assert attrs.phone == "+1234567890"
      assert attrs.website == "https://kidssports.example.com"
      assert attrs.address == "123 Sports Lane"
      assert attrs.logo_url == "https://kidssports.example.com/logo.png"
      assert attrs.verified == true
      assert attrs.verified_at == verified_at
      assert attrs.categories == ["sports", "outdoor"]
    end

    test "excludes id when nil (allows Ecto to auto-generate)" do
      provider = %Provider{
        id: nil,
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ProviderMapper.from_domain(provider)

      refute Map.has_key?(attrs, :id)
      assert attrs.identity_id == "660e8400-e29b-41d4-a716-446655440001"
    end

    test "includes id when present" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ProviderMapper.from_domain(provider)

      assert Map.has_key?(attrs, :id)
      assert attrs.id == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "preserves nil values for optional fields" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ProviderMapper.from_domain(provider)

      assert is_nil(attrs.description)
      assert is_nil(attrs.phone)
      assert is_nil(attrs.website)
      assert is_nil(attrs.address)
      assert is_nil(attrs.logo_url)
      assert is_nil(attrs.verified_at)
    end

    test "does not include timestamps in attrs (Ecto manages them)" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      attrs = ProviderMapper.from_domain(provider)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end

    test "preserves empty categories list" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ProviderMapper.from_domain(provider)

      assert attrs.categories == []
    end

    test "preserves categories list with items" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        business_name: "Test Business",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: ["sports", "education"],
        inserted_at: nil,
        updated_at: nil
      }

      attrs = ProviderMapper.from_domain(provider)

      assert attrs.categories == ["sports", "education"]
    end
  end

  # =============================================================================
  # to_domain_list/1
  # =============================================================================

  describe "to_domain_list/1" do
    test "returns empty list for empty input" do
      result = ProviderMapper.to_domain_list([])

      assert result == []
    end

    test "maps single schema to list with one domain entity" do
      schema = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Single Provider",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      result = ProviderMapper.to_domain_list([schema])

      assert length(result) == 1
      assert [%Provider{business_name: "Single Provider"}] = result
    end

    test "maps multiple schemas to list of domain entities" do
      schema1 = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Provider One",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      schema2 = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Provider Two",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      schema3 = %ProviderSchema{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Provider Three",
        description: nil,
        phone: nil,
        website: nil,
        address: nil,
        logo_url: nil,
        verified: false,
        verified_at: nil,
        categories: [],
        inserted_at: nil,
        updated_at: nil
      }

      result = ProviderMapper.to_domain_list([schema1, schema2, schema3])

      assert length(result) == 3
      assert Enum.all?(result, &match?(%Provider{}, &1))

      business_names = Enum.map(result, & &1.business_name)
      assert "Provider One" in business_names
      assert "Provider Two" in business_names
      assert "Provider Three" in business_names
    end

    test "preserves order of schemas" do
      schemas =
        Enum.map(1..5, fn i ->
          %ProviderSchema{
            id: Ecto.UUID.generate(),
            identity_id: Ecto.UUID.generate(),
            business_name: "Provider #{i}",
            description: nil,
            phone: nil,
            website: nil,
            address: nil,
            logo_url: nil,
            verified: false,
            verified_at: nil,
            categories: [],
            inserted_at: nil,
            updated_at: nil
          }
        end)

      result = ProviderMapper.to_domain_list(schemas)

      expected_names = Enum.map(1..5, &"Provider #{&1}")
      actual_names = Enum.map(result, & &1.business_name)

      assert actual_names == expected_names
    end
  end
end
