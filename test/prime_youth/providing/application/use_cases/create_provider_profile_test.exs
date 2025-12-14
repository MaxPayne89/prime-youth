defmodule PrimeYouth.Providing.Application.UseCases.CreateProviderProfileTest do
  @moduledoc """
  Tests for the CreateProviderProfile use case.

  Tests the orchestration of provider profile creation via the repository port.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Providing.Application.UseCases.CreateProviderProfile
  alias PrimeYouth.Providing.Domain.Models.Provider

  # =============================================================================
  # execute/1 - Successful Creation
  # =============================================================================

  describe "execute/1 successful creation" do
    test "creates provider profile with all fields" do
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

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
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

    test "creates provider profile with minimal fields (identity_id and business_name only)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "My Business"
      }

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
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

    test "auto-generates UUID for provider id" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business"
      }

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
      assert {:ok, _} = Ecto.UUID.cast(provider.id)
    end

    test "generates timestamps on creation" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business"
      }

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
      assert %DateTime{} = provider.inserted_at
      assert %DateTime{} = provider.updated_at
      assert DateTime.compare(provider.inserted_at, provider.updated_at) in [:eq, :lt]
    end

    test "creates provider with verified false and verified_at set (independent fields)" do
      verified_at = ~U[2025-01-15 10:00:00Z]

      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        verified: false,
        verified_at: verified_at
      }

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
      assert provider.verified == false
      assert provider.verified_at == verified_at
    end

    test "creates provider with multiple categories" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Multi Category Provider",
        categories: ["sports", "outdoor", "education", "youth"]
      }

      assert {:ok, %Provider{} = provider} = CreateProviderProfile.execute(attrs)
      assert provider.categories == ["sports", "outdoor", "education", "youth"]
    end
  end

  # =============================================================================
  # execute/1 - Error Cases
  # =============================================================================

  describe "execute/1 error cases" do
    test "returns :duplicate_identity when profile already exists for identity_id" do
      identity_id = Ecto.UUID.generate()
      first_attrs = %{identity_id: identity_id, business_name: "First Provider"}
      second_attrs = %{identity_id: identity_id, business_name: "Second Provider"}

      assert {:ok, _first_provider} = CreateProviderProfile.execute(first_attrs)
      assert {:error, :duplicate_identity} = CreateProviderProfile.execute(second_attrs)
    end

    test "allows creating profiles with different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "First Provider"}
      second_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "Second Provider"}

      assert {:ok, first_provider} = CreateProviderProfile.execute(first_attrs)
      assert {:ok, second_provider} = CreateProviderProfile.execute(second_attrs)

      assert first_provider.id != second_provider.id
      assert first_provider.identity_id != second_provider.identity_id
    end
  end
end
