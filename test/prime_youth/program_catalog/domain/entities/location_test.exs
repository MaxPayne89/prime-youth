defmodule PrimeYouth.ProgramCatalog.Domain.Entities.LocationTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.Entities.Location

  describe "new/1 for physical locations" do
    test "creates physical location with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        name: "Community Recreation Center",
        address_line1: "123 Main Street",
        address_line2: "Suite 100",
        city: "San Francisco",
        state: "CA",
        postal_code: "94102",
        country: "USA",
        is_virtual: false,
        accessibility_notes: "Wheelchair accessible entrance on the west side."
      }

      assert {:ok, %Location{} = location} = Location.new(attrs)
      assert location.name == "Community Recreation Center"
      assert location.city == "San Francisco"
      assert location.is_virtual == false
      assert is_nil(location.virtual_link)
    end

    test "requires name" do
      attrs = physical_location_attrs() |> Map.delete(:name)

      assert {:error, changeset} = Location.new(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "name must be between 2 and 200 characters" do
      attrs = physical_location_attrs()

      # Too short
      assert {:error, changeset} = Location.new(Map.put(attrs, :name, "a"))
      assert "should be at least 2 character(s)" in errors_on(changeset).name

      # Too long
      long_name = String.duplicate("a", 201)
      assert {:error, changeset} = Location.new(Map.put(attrs, :name, long_name))
      assert "should be at most 200 character(s)" in errors_on(changeset).name
    end

    test "requires program_id" do
      attrs = physical_location_attrs() |> Map.delete(:program_id)

      assert {:error, changeset} = Location.new(attrs)
      assert "can't be blank" in errors_on(changeset).program_id
    end

    test "requires address fields for physical location" do
      attrs = physical_location_attrs()

      # Missing address_line1
      assert {:error, changeset} = Location.new(Map.delete(attrs, :address_line1))
      assert "is required for physical locations" in errors_on(changeset).address_line1

      # Missing city
      assert {:error, changeset} = Location.new(Map.delete(attrs, :city))
      assert "is required for physical locations" in errors_on(changeset).city

      # Missing state
      assert {:error, changeset} = Location.new(Map.delete(attrs, :state))
      assert "is required for physical locations" in errors_on(changeset).state
    end

    test "address fields have max length constraints" do
      attrs = physical_location_attrs()

      long_address = String.duplicate("a", 201)
      assert {:error, changeset} = Location.new(Map.put(attrs, :address_line1, long_address))
      assert "should be at most 200 character(s)" in errors_on(changeset).address_line1

      long_city = String.duplicate("a", 101)
      assert {:error, changeset} = Location.new(Map.put(attrs, :city, long_city))
      assert "should be at most 100 character(s)" in errors_on(changeset).city
    end

    test "accessibility_notes limited to 500 characters" do
      attrs = physical_location_attrs()

      long_notes = String.duplicate("a", 501)
      assert {:error, changeset} = Location.new(Map.put(attrs, :accessibility_notes, long_notes))
      assert "should be at most 500 character(s)" in errors_on(changeset).accessibility_notes
    end
  end

  describe "new/1 for virtual locations" do
    test "creates virtual location with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        name: "Online Zoom Session",
        is_virtual: true,
        virtual_link: "https://zoom.us/j/123456789"
      }

      assert {:ok, %Location{} = location} = Location.new(attrs)
      assert location.name == "Online Zoom Session"
      assert location.is_virtual == true
      assert location.virtual_link == "https://zoom.us/j/123456789"
      assert is_nil(location.address_line1)
    end

    test "requires virtual_link for virtual location" do
      attrs = virtual_location_attrs() |> Map.delete(:virtual_link)

      assert {:error, changeset} = Location.new(attrs)
      assert "is required for virtual locations" in errors_on(changeset).virtual_link
    end

    test "virtual_link must be valid URL" do
      attrs = virtual_location_attrs()

      assert {:error, changeset} = Location.new(Map.put(attrs, :virtual_link, "not-a-url"))
      assert "must be a valid URL" in errors_on(changeset).virtual_link

      assert {:error, changeset} =
               Location.new(Map.put(attrs, :virtual_link, "ftp://invalid.com"))

      assert "must be a valid URL" in errors_on(changeset).virtual_link
    end

    test "address fields are optional for virtual location" do
      attrs = virtual_location_attrs()

      assert {:ok, location} = Location.new(attrs)
      assert is_nil(location.address_line1)
      assert is_nil(location.city)
      assert is_nil(location.state)
    end
  end

  describe "business rules" do
    test "defaults is_virtual to false" do
      attrs = physical_location_attrs() |> Map.delete(:is_virtual)

      assert {:ok, location} = Location.new(attrs)
      assert location.is_virtual == false
    end

    test "program can have multiple locations" do
      program_id = Ecto.UUID.generate()

      attrs1 = physical_location_attrs() |> Map.put(:program_id, program_id)

      attrs2 =
        physical_location_attrs()
        |> Map.put(:program_id, program_id)
        |> Map.put(:name, "Alternate Location")

      assert {:ok, location1} = Location.new(attrs1)
      assert {:ok, location2} = Location.new(attrs2)
      assert location1.program_id == location2.program_id
    end

    test "can mix physical and virtual locations" do
      program_id = Ecto.UUID.generate()

      physical = physical_location_attrs() |> Map.put(:program_id, program_id)
      virtual = virtual_location_attrs() |> Map.put(:program_id, program_id)

      assert {:ok, _physical_location} = Location.new(physical)
      assert {:ok, _virtual_location} = Location.new(virtual)
    end
  end

  # Helper functions

  defp physical_location_attrs do
    %{
      id: Ecto.UUID.generate(),
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
      id: Ecto.UUID.generate(),
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
