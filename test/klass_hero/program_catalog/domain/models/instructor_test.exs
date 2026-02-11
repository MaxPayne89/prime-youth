defmodule KlassHero.ProgramCatalog.Domain.Models.InstructorTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Instructor

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    name: "Mike Johnson",
    headshot_url: "https://example.com/photo.jpg"
  }

  describe "new/1" do
    test "creates instructor with all fields" do
      assert {:ok, instructor} = Instructor.new(@valid_attrs)
      assert instructor.id == @valid_attrs.id
      assert instructor.name == "Mike Johnson"
      assert instructor.headshot_url == "https://example.com/photo.jpg"
    end

    test "creates instructor without headshot" do
      attrs = Map.delete(@valid_attrs, :headshot_url)
      assert {:ok, instructor} = Instructor.new(attrs)
      assert instructor.headshot_url == nil
    end

    test "rejects missing id" do
      assert {:error, errors} = Instructor.new(%{@valid_attrs | id: ""})
      assert "ID cannot be empty" in errors
    end

    test "rejects missing name" do
      assert {:error, errors} = Instructor.new(%{@valid_attrs | name: ""})
      assert "Name cannot be empty" in errors
    end
  end

  describe "from_persistence/1" do
    test "reconstructs without validation" do
      assert {:ok, instructor} = Instructor.from_persistence(@valid_attrs)
      assert instructor.name == "Mike Johnson"
    end

    test "errors on missing enforce key" do
      assert {:error, :invalid_persistence_data} =
               Instructor.from_persistence(%{id: "abc"})
    end
  end
end
