defmodule KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListingTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing

  describe "new/1" do
    test "creates a ProgramListing from a map of attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Soccer Camp",
        category: "sports",
        price: Decimal.new("150.00"),
        provider_id: Ecto.UUID.generate(),
        provider_verified: true,
        instructor_name: "Jane Smith",
        inserted_at: ~U[2026-01-01 12:00:00Z]
      }

      listing = ProgramListing.new(attrs)

      assert listing.id == attrs.id
      assert listing.title == "Soccer Camp"
      assert listing.category == "sports"
      assert listing.price == Decimal.new("150.00")
      assert listing.provider_id == attrs.provider_id
      assert listing.provider_verified == true
      assert listing.instructor_name == "Jane Smith"
      assert listing.inserted_at == ~U[2026-01-01 12:00:00Z]
    end

    test "applies defaults for meeting_days and provider_verified" do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Art Workshop",
        provider_id: Ecto.UUID.generate()
      }

      listing = ProgramListing.new(attrs)

      assert listing.meeting_days == []
      assert listing.provider_verified == false
    end

    test "raises on unknown keys (strict construction via struct!)" do
      assert_raise KeyError, fn ->
        ProgramListing.new(%{bogus_field: "nope"})
      end
    end
  end
end
