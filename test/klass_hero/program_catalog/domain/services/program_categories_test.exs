defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramCategoriesTest do
  @moduledoc """
  Tests for the ProgramCategories domain service.

  All tests are pure unit tests with no database dependencies.
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @all_categories ["sports", "arts", "music", "education", "life-skills", "camps", "workshops"]

  describe "valid_categories/0" do
    test "includes all program categories" do
      valid = ProgramCategories.valid_categories()
      assert Enum.all?(@all_categories, &(&1 in valid))
    end

    test "includes 'all' as a filter-only value" do
      assert "all" in ProgramCategories.valid_categories()
    end

    test "returns a list of strings" do
      assert Enum.all?(ProgramCategories.valid_categories(), &is_binary/1)
    end
  end

  describe "validate_filter/1" do
    test "returns the category unchanged when valid" do
      assert ProgramCategories.validate_filter("sports") == "sports"
      assert ProgramCategories.validate_filter("arts") == "arts"
      assert ProgramCategories.validate_filter("music") == "music"
      assert ProgramCategories.validate_filter("education") == "education"
      assert ProgramCategories.validate_filter("life-skills") == "life-skills"
      assert ProgramCategories.validate_filter("camps") == "camps"
      assert ProgramCategories.validate_filter("workshops") == "workshops"
    end

    test "returns 'all' for the special filter value" do
      assert ProgramCategories.validate_filter("all") == "all"
    end

    test "returns default 'all' for nil" do
      assert ProgramCategories.validate_filter(nil) == "all"
    end

    test "returns default 'all' for unknown category" do
      assert ProgramCategories.validate_filter("invalid") == "all"
      assert ProgramCategories.validate_filter("dance") == "all"
      assert ProgramCategories.validate_filter("") == "all"
    end
  end

  describe "valid?/1" do
    test "returns true for each valid program category" do
      Enum.each(@all_categories, fn category ->
        assert ProgramCategories.valid?(category), "expected #{category} to be valid"
      end)
    end

    test "returns true for 'all' filter value" do
      assert ProgramCategories.valid?("all") == true
    end

    test "returns false for unknown categories" do
      refute ProgramCategories.valid?("dance")
      refute ProgramCategories.valid?("coding")
      refute ProgramCategories.valid?("")
    end
  end

  describe "default_category/0" do
    test "returns 'all'" do
      assert ProgramCategories.default_category() == "all"
    end
  end

  describe "program_categories/0" do
    test "returns all categories except 'all'" do
      assert ProgramCategories.program_categories() == @all_categories
    end

    test "does not include 'all'" do
      refute "all" in ProgramCategories.program_categories()
    end
  end

  describe "valid_program_category?/1" do
    test "returns true for each program category" do
      Enum.each(@all_categories, fn category ->
        assert ProgramCategories.valid_program_category?(category),
               "expected #{category} to be valid program category"
      end)
    end

    test "returns false for 'all' (filter-only value)" do
      refute ProgramCategories.valid_program_category?("all")
    end

    test "returns false for unknown categories" do
      refute ProgramCategories.valid_program_category?("dance")
      refute ProgramCategories.valid_program_category?("")
    end
  end

  describe "category list consistency" do
    test "valid_categories contains all program_categories plus 'all'" do
      program_cats = ProgramCategories.program_categories()
      valid_cats = ProgramCategories.valid_categories()

      assert length(valid_cats) == length(program_cats) + 1
      assert "all" in valid_cats
      assert Enum.all?(program_cats, &(&1 in valid_cats))
    end
  end
end
