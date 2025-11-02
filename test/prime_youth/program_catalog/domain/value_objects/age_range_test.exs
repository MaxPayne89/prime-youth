defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.AgeRangeTest do
  @moduledoc """
  Tests for AgeRange value object.

  Tests cover:
  - Valid age range creation
  - Age validation (0-18 for youth programs)
  - Min/max constraint validation
  - Display format
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.AgeRange

  describe "new/2" do
    test "creates age range with valid values" do
      assert {:ok, age_range} = AgeRange.new(5, 12)
      assert age_range.min_age == 5
      assert age_range.max_age == 12
    end

    test "creates age range with same min and max" do
      assert {:ok, age_range} = AgeRange.new(10, 10)
      assert age_range.min_age == 10
      assert age_range.max_age == 10
    end

    test "creates age range at minimum boundary (0)" do
      assert {:ok, age_range} = AgeRange.new(0, 5)
      assert age_range.min_age == 0
    end

    test "creates age range at maximum boundary (18)" do
      assert {:ok, age_range} = AgeRange.new(16, 18)
      assert age_range.max_age == 18
    end

    test "creates full range (0-18)" do
      assert {:ok, age_range} = AgeRange.new(0, 18)
      assert age_range.min_age == 0
      assert age_range.max_age == 18
    end

    test "rejects negative min age" do
      assert {:error, "Min age must be between 0 and 18"} = AgeRange.new(-1, 10)
    end

    test "rejects negative max age" do
      assert {:error, "Max age must be between 0 and 18"} = AgeRange.new(5, -1)
    end

    test "rejects min age above 18" do
      assert {:error, "Min age must be between 0 and 18"} = AgeRange.new(19, 20)
    end

    test "rejects max age above 18" do
      assert {:error, "Max age must be between 0 and 18"} = AgeRange.new(10, 19)
    end

    test "rejects when min age is greater than max age" do
      assert {:error, "Min age cannot be greater than max age"} = AgeRange.new(12, 10)
    end

    test "rejects when min age is much greater than max age" do
      assert {:error, "Min age cannot be greater than max age"} = AgeRange.new(15, 5)
    end

    test "rejects nil min age" do
      assert {:error, "Min age must be an integer"} = AgeRange.new(nil, 10)
    end

    test "rejects nil max age" do
      assert {:error, "Max age must be an integer"} = AgeRange.new(5, nil)
    end

    test "rejects non-integer min age" do
      assert {:error, "Min age must be an integer"} = AgeRange.new("5", 10)
    end

    test "rejects non-integer max age" do
      assert {:error, "Max age must be an integer"} = AgeRange.new(5, "10")
    end

    test "rejects float min age" do
      assert {:error, "Min age must be an integer"} = AgeRange.new(5.5, 10)
    end

    test "rejects float max age" do
      assert {:error, "Max age must be an integer"} = AgeRange.new(5, 10.5)
    end
  end

  describe "display_format/1" do
    test "formats single age range" do
      {:ok, age_range} = AgeRange.new(5, 5)
      assert AgeRange.display_format(age_range) == "Age 5"
    end

    test "formats range with 1 year difference" do
      {:ok, age_range} = AgeRange.new(5, 6)
      assert AgeRange.display_format(age_range) == "Ages 5-6"
    end

    test "formats wide age range" do
      {:ok, age_range} = AgeRange.new(5, 12)
      assert AgeRange.display_format(age_range) == "Ages 5-12"
    end

    test "formats full range" do
      {:ok, age_range} = AgeRange.new(0, 18)
      assert AgeRange.display_format(age_range) == "Ages 0-18"
    end

    test "formats infant range" do
      {:ok, age_range} = AgeRange.new(0, 2)
      assert AgeRange.display_format(age_range) == "Ages 0-2"
    end

    test "formats teen range" do
      {:ok, age_range} = AgeRange.new(13, 18)
      assert AgeRange.display_format(age_range) == "Ages 13-18"
    end

    test "formats early childhood" do
      {:ok, age_range} = AgeRange.new(3, 5)
      assert AgeRange.display_format(age_range) == "Ages 3-5"
    end

    test "formats elementary" do
      {:ok, age_range} = AgeRange.new(6, 11)
      assert AgeRange.display_format(age_range) == "Ages 6-11"
    end

    test "formats middle school" do
      {:ok, age_range} = AgeRange.new(11, 14)
      assert AgeRange.display_format(age_range) == "Ages 11-14"
    end

    test "formats high school" do
      {:ok, age_range} = AgeRange.new(14, 18)
      assert AgeRange.display_format(age_range) == "Ages 14-18"
    end
  end

  describe "overlaps?/2" do
    test "returns true when ranges overlap" do
      {:ok, range1} = AgeRange.new(5, 10)
      {:ok, range2} = AgeRange.new(8, 12)

      assert AgeRange.overlaps?(range1, range2)
    end

    test "returns true when one range contains another" do
      {:ok, range1} = AgeRange.new(5, 15)
      {:ok, range2} = AgeRange.new(8, 12)

      assert AgeRange.overlaps?(range1, range2)
    end

    test "returns true when ranges are identical" do
      {:ok, range1} = AgeRange.new(5, 10)
      {:ok, range2} = AgeRange.new(5, 10)

      assert AgeRange.overlaps?(range1, range2)
    end

    test "returns true when ranges touch at boundary" do
      {:ok, range1} = AgeRange.new(5, 10)
      {:ok, range2} = AgeRange.new(10, 15)

      assert AgeRange.overlaps?(range1, range2)
    end

    test "returns false when ranges do not overlap" do
      {:ok, range1} = AgeRange.new(5, 8)
      {:ok, range2} = AgeRange.new(10, 15)

      refute AgeRange.overlaps?(range1, range2)
    end

    test "returns false when ranges are adjacent but not touching" do
      {:ok, range1} = AgeRange.new(5, 9)
      {:ok, range2} = AgeRange.new(10, 15)

      refute AgeRange.overlaps?(range1, range2)
    end
  end

  describe "contains?/2" do
    test "returns true when range contains age" do
      {:ok, age_range} = AgeRange.new(5, 12)

      assert AgeRange.contains?(age_range, 8)
    end

    test "returns true when age equals min" do
      {:ok, age_range} = AgeRange.new(5, 12)

      assert AgeRange.contains?(age_range, 5)
    end

    test "returns true when age equals max" do
      {:ok, age_range} = AgeRange.new(5, 12)

      assert AgeRange.contains?(age_range, 12)
    end

    test "returns false when age below min" do
      {:ok, age_range} = AgeRange.new(5, 12)

      refute AgeRange.contains?(age_range, 4)
    end

    test "returns false when age above max" do
      {:ok, age_range} = AgeRange.new(5, 12)

      refute AgeRange.contains?(age_range, 13)
    end

    test "returns true for single age range" do
      {:ok, age_range} = AgeRange.new(10, 10)

      assert AgeRange.contains?(age_range, 10)
      refute AgeRange.contains?(age_range, 9)
      refute AgeRange.contains?(age_range, 11)
    end
  end

  describe "value equality" do
    test "age ranges with same min/max are equal" do
      {:ok, range1} = AgeRange.new(5, 12)
      {:ok, range2} = AgeRange.new(5, 12)

      assert range1.min_age == range2.min_age
      assert range1.max_age == range2.max_age
    end

    test "age ranges with different values are not equal" do
      {:ok, range1} = AgeRange.new(5, 12)
      {:ok, range2} = AgeRange.new(6, 12)

      assert range1.min_age != range2.min_age
    end
  end
end
