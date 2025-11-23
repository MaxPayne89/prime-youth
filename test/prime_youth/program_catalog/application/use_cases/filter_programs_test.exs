defmodule PrimeYouth.ProgramCatalog.Application.UseCases.FilterProgramsTest do
  @moduledoc """
  Tests for the FilterPrograms use case.

  This test suite verifies client-side program filtering with word-boundary matching
  and special character normalization. The use case is a pure function with no side effects.
  """

  use ExUnit.Case, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.ProgramCatalog.Application.UseCases.FilterPrograms

  describe "execute/2 - basic filtering" do
    test "returns all programs for empty query" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "")

      assert result == programs
      assert length(result) == 5
    end

    test "matches word at beginning of title" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "after")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "After School Soccer"
    end

    test "matches word in middle of title" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "school")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "After School Soccer"
    end

    test "is case-insensitive" do
      programs = sample_programs()

      result_lower = FilterPrograms.execute(programs, "soccer")
      result_upper = FilterPrograms.execute(programs, "SOCCER")
      result_mixed = FilterPrograms.execute(programs, "SoCcEr")

      assert length(result_lower) == 1
      assert length(result_upper) == 1
      assert length(result_mixed) == 1
      assert result_lower == result_upper
      assert result_upper == result_mixed
      assert Enum.at(result_lower, 0).title == "After School Soccer"
    end

    test "returns empty list for no matches" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "nonexistent")

      assert result == []
      assert Enum.empty?(result)
    end

    test "handles empty programs list" do
      programs = []

      result = FilterPrograms.execute(programs, "soccer")

      assert result == []
      assert Enum.empty?(result)
    end

    test "preserves program order" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440010", title: "Zebra Zone"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440011", title: "Apple Adventure"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440012", title: "Monkey Madness")
      ]

      result = FilterPrograms.execute(programs, "")

      assert length(result) == 3
      assert Enum.at(result, 0).title == "Zebra Zone"
      assert Enum.at(result, 1).title == "Apple Adventure"
      assert Enum.at(result, 2).title == "Monkey Madness"
    end

    test "handles whitespace-only query" do
      programs = sample_programs()

      result_spaces = FilterPrograms.execute(programs, "   ")
      result_tabs = FilterPrograms.execute(programs, "\t\t")
      result_mixed = FilterPrograms.execute(programs, " \t \n ")

      assert result_spaces == programs
      assert result_tabs == programs
      assert result_mixed == programs
    end

    test "handles multiple matches" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440020", title: "Summer Soccer"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440021", title: "Summer Dance"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440022", title: "Winter Soccer")
      ]

      result = FilterPrograms.execute(programs, "summer")

      assert length(result) == 2
      assert Enum.at(result, 0).title == "Summer Soccer"
      assert Enum.at(result, 1).title == "Summer Dance"
    end
  end

  describe "execute/2 - user scenario tests" do
    test "typing 'so' filters to programs with words starting with 'so'" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "so")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "After School Soccer"
    end

    test "typing 'yoga' then 'yoga flow' further refines results" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440030", title: "Kids Yoga Flow"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440031", title: "Adult Yoga Class"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440032", title: "Meditation Flow")
      ]

      result_yoga = FilterPrograms.execute(programs, "yoga")

      assert length(result_yoga) == 2
      titles_yoga = Enum.map(result_yoga, & &1.title)
      assert "Kids Yoga Flow" in titles_yoga
      assert "Adult Yoga Class" in titles_yoga

      result_flow = FilterPrograms.execute(programs, "flow")

      assert length(result_flow) == 2
      titles_flow = Enum.map(result_flow, & &1.title)
      assert "Kids Yoga Flow" in titles_flow
      assert "Meditation Flow" in titles_flow
    end

    test "deleting characters expands results" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440040", title: "Soccer Stars"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440041", title: "Social Club"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440042", title: "Art Adventure")
      ]

      result_soccer = FilterPrograms.execute(programs, "soccer")

      assert length(result_soccer) == 1
      assert Enum.at(result_soccer, 0).title == "Soccer Stars"

      result_soc = FilterPrograms.execute(programs, "soc")

      assert length(result_soc) == 2
      titles = Enum.map(result_soc, & &1.title)
      assert "Soccer Stars" in titles
      assert "Social Club" in titles

      result_so = FilterPrograms.execute(programs, "so")

      assert length(result_so) == 2
    end

    test "clearing search field shows all programs" do
      programs = sample_programs()

      result_filtered = FilterPrograms.execute(programs, "soccer")
      assert length(result_filtered) == 1

      result_cleared = FilterPrograms.execute(programs, "")

      assert result_cleared == programs
      assert length(result_cleared) == 5
    end
  end

  describe "execute/2 - edge cases" do
    test "handles programs with single-word titles" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440050", title: "Soccer"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440051", title: "Dance")
      ]

      result = FilterPrograms.execute(programs, "soc")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "Soccer"
    end

    test "handles very long program titles" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440060",
          title: "Advanced Soccer Training Camp for Young Athletes and Future Champions"
        )
      ]

      result = FilterPrograms.execute(programs, "future")

      assert length(result) == 1
      assert Enum.at(result, 0).title =~ "Future"
    end

    test "treats multi-word query as single search term (no AND logic)" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440070", title: "Kids Soccer Camp"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440071", title: "Adult Soccer League"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440072", title: "Kids Dance Class")
      ]

      result = FilterPrograms.execute(programs, "kids s")

      assert Enum.empty?(result)
    end

    test "rejects substring matches (word-boundary enforcement)" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440080",
          title: "Basketball Training"
        )
      ]

      result = FilterPrograms.execute(programs, "ball")

      assert result == []
    end

    test "handles special characters in program titles" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440090",
          title: "Art! & Crafts"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440091",
          title: "Kids' Yoga"
        )
      ]

      result_art = FilterPrograms.execute(programs, "art")
      result_kids = FilterPrograms.execute(programs, "kids")

      assert length(result_art) == 1
      assert Enum.at(result_art, 0).title == "Art! & Crafts"
      assert length(result_kids) == 1
      assert Enum.at(result_kids, 0).title == "Kids' Yoga"
    end

    test "handles special characters in query" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440100",
          title: "Art & Crafts"
        )
      ]

      result = FilterPrograms.execute(programs, "art!")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "Art & Crafts"
    end

    test "handles titles with multiple consecutive spaces" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440110",
          title: "Summer   Dance    Camp"
        )
      ]

      result = FilterPrograms.execute(programs, "dance")

      assert length(result) == 1
    end
  end
end
