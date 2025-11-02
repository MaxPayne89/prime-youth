defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.LocationTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Location

  describe "changeset/2 for physical locations" do
    test "valid changeset for physical location" do
      attrs = %{
        program_id: Ecto.UUID.generate(),
        name: "Community Recreation Center",
        address_line1: "123 Main Street",
        city: "San Francisco",
        state: "CA",
        postal_code: "94102",
        country: "USA",
        is_virtual: false
      }

      changeset = Location.changeset(%Location{}, attrs)
      assert changeset.valid?
    end

    test "requires name" do
      attrs = physical_location_attrs() |> Map.delete(:name)
      changeset = Location.changeset(%Location{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires program_id" do
      attrs = physical_location_attrs() |> Map.delete(:program_id)
      changeset = Location.changeset(%Location{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).program_id
    end

    test "name must be between 2 and 200 characters" do
      attrs = physical_location_attrs()

      # Too short
      changeset = Location.changeset(%Location{}, Map.put(attrs, :name, "a"))
      refute changeset.valid?

      # Too long
      changeset = Location.changeset(%Location{}, Map.put(attrs, :name, String.duplicate("a", 201)))
      refute changeset.valid?
    end

    test "requires address fields for physical location" do
      attrs = physical_location_attrs()

      # Missing address_line1
      changeset = Location.changeset(%Location{}, Map.delete(attrs, :address_line1))
      refute changeset.valid?

      # Missing city
      changeset = Location.changeset(%Location{}, Map.delete(attrs, :city))
      refute changeset.valid?

      # Missing state
      changeset = Location.changeset(%Location{}, Map.delete(attrs, :state))
      refute changeset.valid?
    end

    test "address fields have max length constraints" do
      attrs = physical_location_attrs()

      long_address = String.duplicate("a", 201)
      changeset = Location.changeset(%Location{}, Map.put(attrs, :address_line1, long_address))
      refute changeset.valid?

      long_city = String.duplicate("a", 101)
      changeset = Location.changeset(%Location{}, Map.put(attrs, :city, long_city))
      refute changeset.valid?
    end
  end

  describe "changeset/2 for virtual locations" do
    test "valid changeset for virtual location" do
      attrs = %{
        program_id: Ecto.UUID.generate(),
        name: "Online Zoom Session",
        is_virtual: true,
        virtual_link: "https://zoom.us/j/123456789"
      }

      changeset = Location.changeset(%Location{}, attrs)
      assert changeset.valid?
    end

    test "requires virtual_link for virtual location" do
      attrs = virtual_location_attrs() |> Map.delete(:virtual_link)
      changeset = Location.changeset(%Location{}, attrs)

      refute changeset.valid?
    end

    test "virtual_link must be valid URL" do
      attrs = virtual_location_attrs()

      changeset = Location.changeset(%Location{}, Map.put(attrs, :virtual_link, "not-a-url"))
      refute changeset.valid?

      changeset = Location.changeset(%Location{}, Map.put(attrs, :virtual_link, "ftp://invalid.com"))
      refute changeset.valid?
    end

    test "address fields are optional for virtual location" do
      attrs = virtual_location_attrs()
      changeset = Location.changeset(%Location{}, attrs)

      assert changeset.valid?
      assert is_nil(Ecto.Changeset.get_field(changeset, :address_line1))
      assert is_nil(Ecto.Changeset.get_field(changeset, :city))
    end
  end

  describe "defaults" do
    test "defaults is_virtual to false" do
      attrs = %{
        program_id: Ecto.UUID.generate(),
        name: "Test Location",
        address_line1: "123 Test St",
        city: "Test City",
        state: "TS"
      }

      changeset = Location.changeset(%Location{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_virtual) == false
    end
  end

  # Helper functions

  defp physical_location_attrs do
    %{
      program_id: Ecto.UUID.generate(),
      name: "Community Recreation Center",
      address_line1: "123 Main Street",
      city: "San Francisco",
      state: "CA",
      postal_code: "94102",
      country: "USA",
      is_virtual: false
    }
  end

  defp virtual_location_attrs do
    %{
      program_id: Ecto.UUID.generate(),
      name: "Online Zoom Session",
      is_virtual: true,
      virtual_link: "https://zoom.us/j/123456789"
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
