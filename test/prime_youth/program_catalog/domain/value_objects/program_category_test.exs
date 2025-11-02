defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.ProgramCategoryTest do
  @moduledoc """
  Tests for ProgramCategory value object.

  Tests cover:
  - Valid category creation
  - Invalid category rejection
  - Display name formatting
  - Listing all categories
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.ProgramCategory

  describe "new/1" do
    test "creates category with valid value" do
      assert {:ok, category} = ProgramCategory.new("sports")
      assert category.value == "sports"
    end

    test "creates category with all valid categories" do
      valid_categories = [
        "sports",
        "arts",
        "stem",
        "academic",
        "music",
        "dance",
        "language",
        "outdoor",
        "leadership",
        "other"
      ]

      for category_name <- valid_categories do
        assert {:ok, _category} = ProgramCategory.new(category_name)
      end
    end

    test "rejects invalid category" do
      assert {:error, "Invalid category: invalid"} = ProgramCategory.new("invalid")
    end

    test "rejects nil category" do
      assert {:error, "Category cannot be nil"} = ProgramCategory.new(nil)
    end

    test "rejects empty string category" do
      assert {:error, "Category cannot be empty"} = ProgramCategory.new("")
    end

    test "normalizes case to lowercase" do
      assert {:ok, category} = ProgramCategory.new("SPORTS")
      assert category.value == "sports"
    end

    test "trims whitespace" do
      assert {:ok, category} = ProgramCategory.new("  sports  ")
      assert category.value == "sports"
    end
  end

  describe "display_name/1" do
    test "returns formatted display name for sports" do
      {:ok, category} = ProgramCategory.new("sports")
      assert ProgramCategory.display_name(category) == "Sports & Athletics"
    end

    test "returns formatted display name for arts" do
      {:ok, category} = ProgramCategory.new("arts")
      assert ProgramCategory.display_name(category) == "Arts & Crafts"
    end

    test "returns formatted display name for stem" do
      {:ok, category} = ProgramCategory.new("stem")
      assert ProgramCategory.display_name(category) == "STEM & Technology"
    end

    test "returns formatted display name for academic" do
      {:ok, category} = ProgramCategory.new("academic")
      assert ProgramCategory.display_name(category) == "Academic Enrichment"
    end

    test "returns formatted display name for music" do
      {:ok, category} = ProgramCategory.new("music")
      assert ProgramCategory.display_name(category) == "Music & Performance"
    end

    test "returns formatted display name for dance" do
      {:ok, category} = ProgramCategory.new("dance")
      assert ProgramCategory.display_name(category) == "Dance & Movement"
    end

    test "returns formatted display name for language" do
      {:ok, category} = ProgramCategory.new("language")
      assert ProgramCategory.display_name(category) == "Language & Culture"
    end

    test "returns formatted display name for outdoor" do
      {:ok, category} = ProgramCategory.new("outdoor")
      assert ProgramCategory.display_name(category) == "Outdoor Adventures"
    end

    test "returns formatted display name for leadership" do
      {:ok, category} = ProgramCategory.new("leadership")
      assert ProgramCategory.display_name(category) == "Leadership & Life Skills"
    end

    test "returns formatted display name for other" do
      {:ok, category} = ProgramCategory.new("other")
      assert ProgramCategory.display_name(category) == "Other Activities"
    end
  end

  describe "all/0" do
    test "returns list of all valid categories" do
      categories = ProgramCategory.all()

      expected = [
        "sports",
        "arts",
        "stem",
        "academic",
        "music",
        "dance",
        "language",
        "outdoor",
        "leadership",
        "other"
      ]

      assert Enum.sort(categories) == Enum.sort(expected)
    end

    test "returns non-empty list" do
      categories = ProgramCategory.all()
      assert length(categories) > 0
    end

    test "all returned categories can be created" do
      categories = ProgramCategory.all()

      for category_name <- categories do
        assert {:ok, _category} = ProgramCategory.new(category_name)
      end
    end
  end

  describe "value equality" do
    test "categories with same value are equal" do
      {:ok, cat1} = ProgramCategory.new("sports")
      {:ok, cat2} = ProgramCategory.new("sports")

      assert cat1.value == cat2.value
    end

    test "categories with different values are not equal" do
      {:ok, cat1} = ProgramCategory.new("sports")
      {:ok, cat2} = ProgramCategory.new("arts")

      assert cat1.value != cat2.value
    end
  end
end
