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
  # execute/1 - Domain Validation
  # =============================================================================

  describe "execute/1 domain validation" do
    test "returns validation_error when identity_id is empty string" do
      attrs = %{
        identity_id: "",
        business_name: "Test Business"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns validation_error when identity_id is whitespace only" do
      attrs = %{
        identity_id: "   ",
        business_name: "Test Business"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns validation_error when business_name is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Business name cannot be empty" in errors
    end

    test "returns validation_error when business_name exceeds 200 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: String.duplicate("a", 201)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Business name must be 200 characters or less" in errors
    end

    test "returns validation_error when description is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Description cannot be empty if provided" in errors
    end

    test "returns validation_error when description exceeds 1000 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: String.duplicate("a", 1001)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Description must be 1000 characters or less" in errors
    end

    test "returns validation_error when phone is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        phone: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "returns validation_error when phone exceeds 20 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        phone: String.duplicate("1", 21)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Phone must be 20 characters or less" in errors
    end

    test "returns validation_error when website does not start with https://" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "http://example.com"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Website must start with https://" in errors
    end

    test "returns validation_error when website is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Website cannot be empty if provided" in errors
    end

    test "returns validation_error when website exceeds 500 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "https://" <> String.duplicate("a", 494)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Website must be 500 characters or less" in errors
    end

    test "returns validation_error when address is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        address: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Address cannot be empty if provided" in errors
    end

    test "returns validation_error when address exceeds 500 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        address: String.duplicate("a", 501)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Address must be 500 characters or less" in errors
    end

    test "returns validation_error when logo_url is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        logo_url: ""
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Logo URL cannot be empty if provided" in errors
    end

    test "returns validation_error when logo_url exceeds 500 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        logo_url: String.duplicate("a", 501)
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Logo URL must be 500 characters or less" in errors
    end

    test "returns validation_error when verified is not a boolean" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        verified: "yes"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Verified must be a boolean" in errors
    end

    test "returns validation_error when categories is not a list" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        categories: "sports"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Categories must be a list" in errors
    end

    test "returns validation_error when categories contains non-string values" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        categories: ["sports", 123, "outdoor"]
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Categories must be a list of strings" in errors
    end

    test "returns multiple validation errors for multiple invalid fields" do
      attrs = %{
        identity_id: "",
        business_name: "",
        phone: String.duplicate("1", 21),
        website: "http://example.com"
      }

      assert {:error, {:validation_error, errors}} = CreateProviderProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
      assert "Business name cannot be empty" in errors
      assert "Phone must be 20 characters or less" in errors
      assert "Website must start with https://" in errors
      assert length(errors) == 4
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
