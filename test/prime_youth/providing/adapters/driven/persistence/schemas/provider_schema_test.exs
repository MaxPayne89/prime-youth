defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchemaTest do
  @moduledoc """
  Tests for the ProviderSchema Ecto schema.

  Tests changeset validations and database constraints.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema

  # =============================================================================
  # changeset/2 - Valid Changesets
  # =============================================================================

  describe "changeset/2 with valid attributes" do
    test "creates valid changeset with all fields" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane, Athletic City",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: true,
        verified_at: ~U[2025-01-15 10:00:00Z],
        categories: ["sports", "outdoor"]
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :identity_id) == attrs.identity_id
      assert get_change(changeset, :business_name) == "Kids Sports Academy"
      assert get_change(changeset, :description) == "Premier youth sports training"
      assert get_change(changeset, :phone) == "+1234567890"
      assert get_change(changeset, :website) == "https://kidssports.example.com"
      assert get_change(changeset, :address) == "123 Sports Lane, Athletic City"
      assert get_change(changeset, :logo_url) == "https://kidssports.example.com/logo.png"
      assert get_change(changeset, :verified) == true
      assert get_change(changeset, :verified_at) == ~U[2025-01-15 10:00:00Z]
      assert get_change(changeset, :categories) == ["sports", "outdoor"]
    end

    test "creates valid changeset with only required fields" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "My Business"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :identity_id) == attrs.identity_id
      assert get_change(changeset, :business_name) == "My Business"
      assert is_nil(get_change(changeset, :description))
      assert is_nil(get_change(changeset, :phone))
      assert is_nil(get_change(changeset, :website))
      assert is_nil(get_change(changeset, :address))
      assert is_nil(get_change(changeset, :logo_url))
    end

    test "creates valid changeset with business_name at boundary (200 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: String.duplicate("a", 200)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with description at boundary (1000 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: String.duplicate("a", 1000)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with phone at boundary (20 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        phone: String.duplicate("1", 20)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with website at boundary (500 chars)" do
      # https:// (8) + path (488) + .com (4) = 500 characters
      long_path = String.duplicate("a", 488)

      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "https://#{long_path}.com"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with address at boundary (500 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        address: String.duplicate("a", 500)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with logo_url at boundary (500 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        logo_url: String.duplicate("a", 500)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # changeset/2 - Required Field Validation
  # =============================================================================

  describe "changeset/2 identity_id validation" do
    test "returns invalid changeset when identity_id is missing" do
      attrs = %{business_name: "Test Business"}

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).identity_id
    end

    test "returns invalid changeset when identity_id is nil" do
      attrs = %{identity_id: nil, business_name: "Test Business"}

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).identity_id
    end
  end

  describe "changeset/2 business_name validation" do
    test "returns invalid changeset when business_name is missing" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).business_name
    end

    test "returns invalid changeset when business_name is nil" do
      attrs = %{identity_id: Ecto.UUID.generate(), business_name: nil}

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).business_name
    end

    test "returns invalid changeset when business_name exceeds 200 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: String.duplicate("a", 201)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 200 character(s)" in errors_on(changeset).business_name
    end
  end

  # =============================================================================
  # changeset/2 - Optional Field Validation
  # =============================================================================

  describe "changeset/2 description validation" do
    test "returns invalid changeset when description exceeds 1000 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: String.duplicate("a", 1001)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).description
    end

    test "accepts nil description" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        description: nil
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "changeset/2 phone validation" do
    test "returns invalid changeset when phone exceeds 20 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        phone: String.duplicate("1", 21)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 20 character(s)" in errors_on(changeset).phone
    end

    test "accepts nil phone" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        phone: nil
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "changeset/2 website validation" do
    test "returns invalid changeset when website exceeds 500 characters" do
      # https:// (8) + path (489) + .com (4) = 501 characters
      long_path = String.duplicate("a", 489)

      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "https://#{long_path}.com"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).website
    end

    test "returns invalid changeset when website does not start with https://" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "http://example.com"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "must start with https://" in errors_on(changeset).website
    end

    test "returns invalid changeset for plain domain website" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "example.com"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "must start with https://" in errors_on(changeset).website
    end

    test "accepts valid https website" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: "https://example.com"
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end

    test "accepts nil website" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        website: nil
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "changeset/2 address validation" do
    test "returns invalid changeset when address exceeds 500 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        address: String.duplicate("a", 501)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).address
    end

    test "accepts nil address" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        address: nil
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "changeset/2 logo_url validation" do
    test "returns invalid changeset when logo_url exceeds 500 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        logo_url: String.duplicate("a", 501)
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).logo_url
    end

    test "accepts nil logo_url" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        logo_url: nil
      }

      changeset = ProviderSchema.changeset(%ProviderSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # Unique Constraint on identity_id
  # =============================================================================

  describe "unique constraint on identity_id" do
    test "prevents duplicate identity_id" do
      identity_id = Ecto.UUID.generate()

      first_attrs = %{identity_id: identity_id, business_name: "First Provider"}
      first_changeset = ProviderSchema.changeset(%ProviderSchema{}, first_attrs)
      {:ok, _first_provider} = Repo.insert(first_changeset)

      second_attrs = %{identity_id: identity_id, business_name: "Second Provider"}
      second_changeset = ProviderSchema.changeset(%ProviderSchema{}, second_attrs)

      {:error, changeset} = Repo.insert(second_changeset)

      refute changeset.valid?

      assert "Provider profile already exists for this identity" in errors_on(changeset).identity_id
    end

    test "allows different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "First Provider"}
      first_changeset = ProviderSchema.changeset(%ProviderSchema{}, first_attrs)
      {:ok, _first_provider} = Repo.insert(first_changeset)

      second_attrs = %{identity_id: Ecto.UUID.generate(), business_name: "Second Provider"}
      second_changeset = ProviderSchema.changeset(%ProviderSchema{}, second_attrs)
      {:ok, second_provider} = Repo.insert(second_changeset)

      assert second_provider.business_name == "Second Provider"
    end
  end
end
