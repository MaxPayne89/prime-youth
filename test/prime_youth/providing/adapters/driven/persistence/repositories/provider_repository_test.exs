defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepositoryTest do
  @moduledoc """
  Tests for the ProviderRepository adapter.

  Tests database operations for provider profiles including creation,
  retrieval, and existence checks.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository
  alias PrimeYouth.Providing.Domain.Models.Provider

  # =============================================================================
  # create_provider_profile/1
  # =============================================================================

  describe "create_provider_profile/1" do
    test "creates provider with all fields and returns domain entity" do
      verified_at = ~U[2025-01-15 10:00:00Z]

      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane, Athletic City",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: true,
        verified_at: verified_at,
        categories: ["sports", "outdoor"]
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert is_binary(provider.id)
      assert provider.identity_id == attrs.identity_id
      assert provider.business_name == "Kids Sports Academy"
      assert provider.description == "Premier youth sports training"
      assert provider.phone == "+1234567890"
      assert provider.website == "https://kidssports.example.com"
      assert provider.address == "123 Sports Lane, Athletic City"
      assert provider.logo_url == "https://kidssports.example.com/logo.png"
      assert provider.verified == true
      assert provider.verified_at == verified_at
      assert provider.categories == ["sports", "outdoor"]
      assert %DateTime{} = provider.inserted_at
      assert %DateTime{} = provider.updated_at
    end

    test "creates provider with minimal fields (identity_id and business_name only)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "My Business"
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert is_binary(provider.id)
      assert provider.identity_id == attrs.identity_id
      assert provider.business_name == "My Business"
      assert is_nil(provider.description)
      assert is_nil(provider.phone)
      assert is_nil(provider.website)
      assert is_nil(provider.address)
      assert is_nil(provider.logo_url)
      assert provider.verified == false
      assert is_nil(provider.verified_at)
      assert provider.categories == []
    end

    test "auto-generates UUID for id field" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business"
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert {:ok, _} = Ecto.UUID.cast(provider.id)
    end

    test "returns :duplicate_identity error when profile exists for identity_id" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "First Provider"}

      assert {:ok, _first_provider} = ProviderRepository.create_provider_profile(attrs)

      second_attrs = %{identity_id: identity_id, business_name: "Second Provider"}

      assert {:error, :duplicate_identity} =
               ProviderRepository.create_provider_profile(second_attrs)
    end

    test "allows creating profiles with different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "First Provider"}
      second_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "Second Provider"}

      assert {:ok, first_provider} = ProviderRepository.create_provider_profile(first_attrs)
      assert {:ok, second_provider} = ProviderRepository.create_provider_profile(second_attrs)

      assert first_provider.id != second_provider.id
      assert first_provider.identity_id != second_provider.identity_id
    end

    test "creates provider with verified false and verified_at set (independent fields)" do
      verified_at = ~U[2025-01-15 10:00:00Z]

      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        verified: false,
        verified_at: verified_at
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert provider.verified == false
      assert provider.verified_at == verified_at
    end

    test "creates provider with empty categories list" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        categories: []
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert provider.categories == []
    end

    test "creates provider with multiple categories" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Multi Category Provider",
        categories: ["sports", "outdoor", "education", "youth"]
      }

      assert {:ok, %Provider{} = provider} = ProviderRepository.create_provider_profile(attrs)
      assert provider.categories == ["sports", "outdoor", "education", "youth"]
    end
  end

  # =============================================================================
  # get_by_identity_id/1
  # =============================================================================

  describe "get_by_identity_id/1" do
    test "retrieves existing provider and returns domain entity" do
      identity_id = Ecto.UUID.generate()
      verified_at = ~U[2025-01-10 08:00:00Z]

      attrs = %{
        identity_id: identity_id,
        business_name: "Kids Sports Academy",
        description: "Youth sports training",
        phone: "+1987654321",
        website: "https://example.com",
        address: "123 Main St",
        logo_url: "https://example.com/logo.png",
        verified: true,
        verified_at: verified_at,
        categories: ["sports"]
      }

      {:ok, created_provider} = ProviderRepository.create_provider_profile(attrs)

      assert {:ok, %Provider{} = retrieved_provider} =
               ProviderRepository.get_by_identity_id(identity_id)

      assert retrieved_provider.id == created_provider.id
      assert retrieved_provider.identity_id == identity_id
      assert retrieved_provider.business_name == "Kids Sports Academy"
      assert retrieved_provider.description == "Youth sports training"
      assert retrieved_provider.phone == "+1987654321"
      assert retrieved_provider.website == "https://example.com"
      assert retrieved_provider.address == "123 Main St"
      assert retrieved_provider.logo_url == "https://example.com/logo.png"
      assert retrieved_provider.verified == true
      assert retrieved_provider.verified_at == verified_at
      assert retrieved_provider.categories == ["sports"]
    end

    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ProviderRepository.get_by_identity_id(non_existent_id)
    end

    test "retrieves correct provider when multiple exist" do
      first_identity = Ecto.UUID.generate()
      second_identity = Ecto.UUID.generate()

      {:ok, _first} =
        ProviderRepository.create_provider_profile(%{
          identity_id: first_identity,
          business_name: "First Provider"
        })

      {:ok, second} =
        ProviderRepository.create_provider_profile(%{
          identity_id: second_identity,
          business_name: "Second Provider"
        })

      assert {:ok, retrieved} = ProviderRepository.get_by_identity_id(second_identity)
      assert retrieved.id == second.id
      assert retrieved.business_name == "Second Provider"
    end

    test "retrieves provider with all optional fields nil" do
      identity_id = Ecto.UUID.generate()

      {:ok, _created} =
        ProviderRepository.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "Minimal Provider"
        })

      assert {:ok, retrieved} = ProviderRepository.get_by_identity_id(identity_id)
      assert retrieved.business_name == "Minimal Provider"
      assert is_nil(retrieved.description)
      assert is_nil(retrieved.phone)
      assert is_nil(retrieved.website)
      assert is_nil(retrieved.address)
      assert is_nil(retrieved.logo_url)
    end
  end

  # =============================================================================
  # has_profile?/1
  # =============================================================================

  describe "has_profile?/1" do
    test "returns true when provider profile exists" do
      identity_id = Ecto.UUID.generate()

      {:ok, _provider} =
        ProviderRepository.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "Test Business"
        })

      assert ProviderRepository.has_profile?(identity_id) == true
    end

    test "returns false when provider profile does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert ProviderRepository.has_profile?(non_existent_id) == false
    end

    test "returns correct result after creating multiple profiles" do
      existing_identity = Ecto.UUID.generate()
      non_existing_identity = Ecto.UUID.generate()

      {:ok, _} =
        ProviderRepository.create_provider_profile(%{
          identity_id: existing_identity,
          business_name: "Existing Provider"
        })

      assert ProviderRepository.has_profile?(existing_identity) == true
      assert ProviderRepository.has_profile?(non_existing_identity) == false
    end

    test "returns true for provider with minimal fields" do
      identity_id = Ecto.UUID.generate()

      {:ok, _} =
        ProviderRepository.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "Minimal"
        })

      assert ProviderRepository.has_profile?(identity_id) == true
    end

    test "returns true for provider with all fields populated" do
      identity_id = Ecto.UUID.generate()

      {:ok, _} =
        ProviderRepository.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "Full Provider",
          description: "Description",
          phone: "+1234567890",
          website: "https://example.com",
          address: "123 Main St",
          logo_url: "https://example.com/logo.png",
          verified: true,
          verified_at: ~U[2025-01-15 10:00:00Z],
          categories: ["sports", "outdoor"]
        })

      assert ProviderRepository.has_profile?(identity_id) == true
    end
  end
end
