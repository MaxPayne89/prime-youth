defmodule KlassHero.Family.Domain.Services.ReferralCodeGeneratorTest do
  @moduledoc """
  Tests for the ReferralCodeGenerator domain service.

  All tests are pure unit tests with no database dependencies.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Services.ReferralCodeGenerator

  describe "generate/2 - basic format" do
    test "produces code in FIRSTNAME-LOCATION-YEAR format" do
      code = ReferralCodeGenerator.generate("Alice", location: "BERLIN", year_suffix: "26")
      assert code == "ALICE-BERLIN-26"
    end

    test "uppercases the first name" do
      code = ReferralCodeGenerator.generate("alice", location: "LONDON", year_suffix: "26")
      assert code == "ALICE-LONDON-26"
    end

    test "uses default location BERLIN when not specified" do
      code = ReferralCodeGenerator.generate("Bob", year_suffix: "26")
      assert String.starts_with?(code, "BOB-BERLIN-")
    end

    test "uses current year suffix when not specified" do
      code = ReferralCodeGenerator.generate("Carol")
      year_suffix = Date.utc_today().year |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")
      assert String.ends_with?(code, "-#{year_suffix}")
    end
  end

  describe "generate/2 - first name extraction" do
    test "extracts only the first word from a full name" do
      code = ReferralCodeGenerator.generate("John Smith", location: "NYC", year_suffix: "26")
      assert code == "JOHN-NYC-26"
    end

    test "handles three-part names by using only the first word" do
      code = ReferralCodeGenerator.generate("Mary Jane Watson", location: "NYC", year_suffix: "26")
      assert code == "MARY-NYC-26"
    end

    test "handles single-word name" do
      code = ReferralCodeGenerator.generate("Madonna", location: "PARIS", year_suffix: "26")
      assert code == "MADONNA-PARIS-26"
    end

    test "trims trailing spaces from extracted first name" do
      code = ReferralCodeGenerator.generate("Hans Mueller", location: "BERLIN", year_suffix: "25")
      assert code == "HANS-BERLIN-25"
    end
  end

  describe "generate/2 - year suffix formatting" do
    test "pads single-digit year string to two characters" do
      code = ReferralCodeGenerator.generate("Test", location: "BERLIN", year_suffix: "09")
      assert code == "TEST-BERLIN-09"
    end

    test "preserves two-digit year suffix as-is" do
      code = ReferralCodeGenerator.generate("Test", location: "BERLIN", year_suffix: "99")
      assert code == "TEST-BERLIN-99"
    end

    test "auto-generates year suffix as two-digit string" do
      code = ReferralCodeGenerator.generate("Test", location: "BERLIN")
      [_, _, year] = String.split(code, "-")
      assert String.length(year) == 2
      assert year =~ ~r/^\d{2}$/
    end
  end

  describe "generate/2 - custom location" do
    test "uses provided location string" do
      code = ReferralCodeGenerator.generate("Emma", location: "MUNICH", year_suffix: "26")
      assert code == "EMMA-MUNICH-26"
    end

    test "location is interpolated as-is (caller controls casing)" do
      code = ReferralCodeGenerator.generate("Emma", location: "munich", year_suffix: "26")
      assert code == "EMMA-munich-26"
    end
  end
end
