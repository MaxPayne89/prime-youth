defmodule PrimeYouth.Providing.Domain.Models.ProviderTest do
  @moduledoc """
  Tests for the Provider domain model.

  These tests verify business logic and validation rules for the Provider entity.
  Tests are organized by function and validation type.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Providing.Domain.Models.Provider

  describe "new/1 valid providers" do
    test "creates a provider with all fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training center",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane, Athletic City, AC 12345",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: true,
        verified_at: ~U[2025-01-15 10:00:00Z],
        categories: ["sports", "outdoor", "camps"],
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.id == attrs.id
      assert provider.identity_id == attrs.identity_id
      assert provider.business_name == attrs.business_name
      assert provider.description == attrs.description
      assert provider.phone == attrs.phone
      assert provider.website == attrs.website
      assert provider.address == attrs.address
      assert provider.logo_url == attrs.logo_url
      assert provider.verified == true
      assert provider.verified_at == ~U[2025-01-15 10:00:00Z]
      assert provider.categories == ["sports", "outdoor", "camps"]
    end

    test "creates a provider with minimal required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "My Business"
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.id == attrs.id
      assert provider.identity_id == attrs.identity_id
      assert provider.business_name == attrs.business_name
      assert provider.description == nil
      assert provider.phone == nil
      assert provider.website == nil
      assert provider.address == nil
      assert provider.logo_url == nil
      assert provider.verified == false
      assert provider.verified_at == nil
      assert provider.categories == []
    end

    test "applies default values for verified and categories" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business"
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified == false
      assert provider.categories == []
    end
  end

  describe "new/1 identity_id validation" do
    test "rejects empty identity_id" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "",
        business_name: "Test Business"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "rejects whitespace-only identity_id" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "   ",
        business_name: "Test Business"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "rejects non-string identity_id" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: 12345,
        business_name: "Test Business"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Identity ID must be a string" in errors
    end

    test "accepts identity_id with leading/trailing spaces" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "  valid-id  ",
        business_name: "Test Business"
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end
  end

  describe "new/1 business_name validation" do
    test "rejects empty business_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Business name cannot be empty" in errors
    end

    test "rejects whitespace-only business_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "   "
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Business name cannot be empty" in errors
    end

    test "rejects business_name over 200 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: String.duplicate("a", 201)
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Business name must be 200 characters or less" in errors
    end

    test "accepts business_name at exactly 200 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: String.duplicate("a", 200)
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "accepts single character business_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "X"
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string business_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Business name must be a string" in errors
    end
  end

  describe "new/1 description validation" do
    test "accepts nil description" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects empty description when provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Description cannot be empty if provided" in errors
    end

    test "rejects whitespace-only description" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: "   "
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Description cannot be empty if provided" in errors
    end

    test "rejects description over 1000 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: String.duplicate("a", 1001)
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Description must be 1000 characters or less" in errors
    end

    test "accepts description at exactly 1000 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: String.duplicate("a", 1000)
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string description" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        description: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Description must be a string" in errors
    end
  end

  describe "new/1 phone validation" do
    test "accepts nil phone" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects empty phone when provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "rejects whitespace-only phone" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: "   "
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "rejects phone over 20 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: String.duplicate("1", 21)
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Phone must be 20 characters or less" in errors
    end

    test "accepts phone at exactly 20 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: String.duplicate("1", 20)
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string phone" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        phone: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Phone must be a string" in errors
    end
  end

  describe "new/1 website validation" do
    test "accepts nil website" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects empty website when provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Website cannot be empty if provided" in errors
    end

    test "rejects website not starting with https://" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "http://example.com"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Website must start with https://" in errors
    end

    test "rejects website with plain domain" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "example.com"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Website must start with https://" in errors
    end

    test "accepts valid https website" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "https://example.com"
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "accepts https website with path" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "https://example.com/about/us"
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects website over 500 characters" do
      # https:// (8) + path (489) + .com (4) = 501 characters
      long_path = String.duplicate("a", 489)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "https://#{long_path}.com"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Website must be 500 characters or less" in errors
    end

    test "accepts website at exactly 500 characters" do
      # https:// (8) + path (488) + .com (4) = 500 characters
      long_path = String.duplicate("a", 488)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "https://#{long_path}.com"
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string website" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Website must be a string" in errors
    end
  end

  describe "new/1 address validation" do
    test "accepts nil address" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects empty address when provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Address cannot be empty if provided" in errors
    end

    test "rejects whitespace-only address" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: "   "
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Address cannot be empty if provided" in errors
    end

    test "rejects address over 500 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: String.duplicate("a", 501)
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Address must be 500 characters or less" in errors
    end

    test "accepts address at exactly 500 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: String.duplicate("a", 500)
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string address" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        address: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Address must be a string" in errors
    end
  end

  describe "new/1 logo_url validation" do
    test "accepts nil logo_url" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects empty logo_url when provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: ""
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Logo URL cannot be empty if provided" in errors
    end

    test "rejects whitespace-only logo_url" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: "   "
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Logo URL cannot be empty if provided" in errors
    end

    test "rejects logo_url over 500 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: String.duplicate("a", 501)
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Logo URL must be 500 characters or less" in errors
    end

    test "accepts logo_url at exactly 500 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: String.duplicate("a", 500)
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "rejects non-string logo_url" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        logo_url: 12345
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Logo URL must be a string" in errors
    end
  end

  describe "new/1 verified validation" do
    test "accepts nil verified (defaults to false)" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business"
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified == false
    end

    test "accepts true verified" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified: true
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified == true
    end

    test "accepts false verified" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified: false
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified == false
    end

    test "rejects non-boolean verified" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified: "true"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Verified must be a boolean" in errors
    end
  end

  describe "new/1 verified_at validation" do
    test "accepts nil verified_at" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified_at: nil
      }

      assert {:ok, _provider} = Provider.new(attrs)
    end

    test "accepts DateTime verified_at" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified_at: ~U[2025-01-15 10:00:00Z]
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified_at == ~U[2025-01-15 10:00:00Z]
    end

    test "verified_at is independent of verified flag" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified: false,
        verified_at: ~U[2025-01-15 10:00:00Z]
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.verified == false
      assert provider.verified_at == ~U[2025-01-15 10:00:00Z]
    end

    test "rejects non-DateTime verified_at" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified_at: "2025-01-15"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Verified at must be a DateTime" in errors
    end
  end

  describe "new/1 categories validation" do
    test "defaults to empty list when not provided" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business"
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.categories == []
    end

    test "accepts empty list categories" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        categories: []
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.categories == []
    end

    test "accepts list of strings" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        categories: ["sports", "outdoor", "camps"]
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.categories == ["sports", "outdoor", "camps"]
    end

    test "accepts single category" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        categories: ["sports"]
      }

      assert {:ok, provider} = Provider.new(attrs)
      assert provider.categories == ["sports"]
    end

    test "rejects list containing non-strings" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        categories: ["sports", 123, "camps"]
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Categories must be a list of strings" in errors
    end

    test "rejects non-list categories" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        categories: "sports"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Categories must be a list" in errors
    end
  end

  describe "new/1 multiple validation errors" do
    test "returns all errors when multiple fields are invalid" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "",
        business_name: "",
        website: "http://insecure.com",
        verified: "maybe"
      }

      assert {:error, errors} = Provider.new(attrs)
      assert "Identity ID cannot be empty" in errors
      assert "Business name cannot be empty" in errors
      assert "Website must start with https://" in errors
      assert "Verified must be a boolean" in errors
    end
  end

  describe "valid?/1" do
    test "returns true for valid provider" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Valid Business"
      }

      {:ok, provider} = Provider.new(attrs)
      assert Provider.valid?(provider)
    end

    test "returns false for provider with empty identity_id" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "",
        business_name: "Test Business"
      }

      refute Provider.valid?(provider)
    end

    test "returns false for provider with empty business_name" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: ""
      }

      refute Provider.valid?(provider)
    end

    test "returns false for provider with invalid website" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        website: "http://insecure.com"
      }

      refute Provider.valid?(provider)
    end
  end

  describe "verified?/1" do
    test "returns true when verified is true" do
      {:ok, provider} =
        Provider.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "660e8400-e29b-41d4-a716-446655440000",
          business_name: "Verified Business",
          verified: true
        })

      assert Provider.verified?(provider)
    end

    test "returns false when verified is false" do
      {:ok, provider} =
        Provider.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "660e8400-e29b-41d4-a716-446655440000",
          business_name: "Unverified Business",
          verified: false
        })

      refute Provider.verified?(provider)
    end

    test "returns false when verified is nil" do
      provider = %Provider{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440000",
        business_name: "Test Business",
        verified: nil
      }

      refute Provider.verified?(provider)
    end
  end
end
