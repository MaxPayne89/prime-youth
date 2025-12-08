defmodule PrimeYouth.ProgramCatalog.Application.UseCases.FilterProgramsTest do
  @moduledoc """
  Tests for the FilterPrograms use case.

  This test suite verifies client-side program filtering with word-boundary matching
  and special character normalization. The use case is a pure function with no side effects.
  """

  use ExUnit.Case, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.ProgramCatalog.Application.UseCases.FilterPrograms

  # Test helper: Assert that result contains exactly one program with the expected title
  defp assert_single_match(result, expected_title) do
    assert length(result) == 1
    assert Enum.at(result, 0).title == expected_title
  end

  # Test helper: Assert that programs list includes all expected titles
  defp assert_titles_include(programs, expected_titles) do
    actual_titles = Enum.map(programs, & &1.title)

    for title <- expected_titles do
      assert title in actual_titles,
             "Expected title '#{title}' not found in results: #{inspect(actual_titles)}"
    end
  end

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

      assert_single_match(result, "After School Soccer")
    end

    test "matches word in middle of title" do
      programs = sample_programs()

      result = FilterPrograms.execute(programs, "school")

      assert_single_match(result, "After School Soccer")
    end

    test "is case-insensitive" do
      programs = sample_programs()

      result_lower = FilterPrograms.execute(programs, "soccer")
      result_upper = FilterPrograms.execute(programs, "SOCCER")
      result_mixed = FilterPrograms.execute(programs, "SoCcEr")

      assert result_lower == result_upper
      assert result_upper == result_mixed
      assert_single_match(result_lower, "After School Soccer")
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

      assert_single_match(result, "After School Soccer")
    end

    test "typing 'yoga' then 'yoga flow' further refines results" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440030", title: "Kids Yoga Flow"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440031", title: "Adult Yoga Class"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440032", title: "Meditation Flow")
      ]

      result_yoga = FilterPrograms.execute(programs, "yoga")
      assert length(result_yoga) == 2
      assert_titles_include(result_yoga, ["Kids Yoga Flow", "Adult Yoga Class"])

      result_flow = FilterPrograms.execute(programs, "flow")
      assert length(result_flow) == 2
      assert_titles_include(result_flow, ["Kids Yoga Flow", "Meditation Flow"])
    end

    test "deleting characters expands results" do
      programs = [
        build(:program, id: "550e8400-e29b-41d4-a716-446655440040", title: "Soccer Stars"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440041", title: "Social Club"),
        build(:program, id: "550e8400-e29b-41d4-a716-446655440042", title: "Art Adventure")
      ]

      result_soccer = FilterPrograms.execute(programs, "soccer")
      assert_single_match(result_soccer, "Soccer Stars")

      result_soc = FilterPrograms.execute(programs, "soc")
      assert length(result_soc) == 2
      assert_titles_include(result_soc, ["Soccer Stars", "Social Club"])

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

      assert_single_match(result, "Soccer")
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

    test "matches with special chars: 'art!' matches 'Art! & Crafts'" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440101",
          title: "Art! & Crafts"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440102",
          title: "Dance Class"
        )
      ]

      result = FilterPrograms.execute(programs, "art!")

      assert length(result) == 1
      assert Enum.at(result, 0).title == "Art! & Crafts"
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

  describe "execute/2 - international characters" do
    test "handles accented characters in program titles" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440120",
          title: "École de Danse"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440121",
          title: "Niños Yoga"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440122",
          title: "Café Cultural"
        )
      ]

      result_ecole = FilterPrograms.execute(programs, "école")
      assert_single_match(result_ecole, "École de Danse")

      result_ninos = FilterPrograms.execute(programs, "niños")
      assert_single_match(result_ninos, "Niños Yoga")

      result_cafe = FilterPrograms.execute(programs, "café")
      assert_single_match(result_cafe, "Café Cultural")
    end

    test "is case-insensitive with accented characters" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440130",
          title: "École de Français"
        )
      ]

      result_lower = FilterPrograms.execute(programs, "école")
      result_upper = FilterPrograms.execute(programs, "ÉCOLE")
      result_mixed = FilterPrograms.execute(programs, "ÉcOlE")

      assert result_lower == result_upper
      assert result_upper == result_mixed
      assert_single_match(result_lower, "École de Français")
    end

    test "handles German special characters" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440140",
          title: "Fußball für Kinder"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440141",
          title: "Äpfel und Birnen"
        )
      ]

      result_fussball = FilterPrograms.execute(programs, "fußball")
      assert_single_match(result_fussball, "Fußball für Kinder")

      result_apfel = FilterPrograms.execute(programs, "äpfel")
      assert_single_match(result_apfel, "Äpfel und Birnen")
    end

    test "handles Portuguese special characters" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440150",
          title: "São Paulo Soccer"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440151",
          title: "Ação Cultural"
        )
      ]

      result_sao = FilterPrograms.execute(programs, "são")
      assert_single_match(result_sao, "São Paulo Soccer")

      result_acao = FilterPrograms.execute(programs, "ação")
      assert_single_match(result_acao, "Ação Cultural")
    end

    test "handles Cyrillic characters" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440160",
          title: "Москва Basketball"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440161",
          title: "Київ Dance"
        )
      ]

      result_moskva = FilterPrograms.execute(programs, "москва")
      assert_single_match(result_moskva, "Москва Basketball")

      result_kyiv = FilterPrograms.execute(programs, "київ")
      assert_single_match(result_kyiv, "Київ Dance")
    end

    test "handles Greek characters" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440170",
          title: "Αθήνα Yoga"
        ),
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440171",
          title: "Ελληνικά Lessons"
        )
      ]

      result_athina = FilterPrograms.execute(programs, "αθήνα")
      assert_single_match(result_athina, "Αθήνα Yoga")

      result_ellinika = FilterPrograms.execute(programs, "ελληνικά")
      assert_single_match(result_ellinika, "Ελληνικά Lessons")
    end

    test "handles mixed Unicode characters in single title" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440180",
          title: "Café São Москва École"
        )
      ]

      result_cafe = FilterPrograms.execute(programs, "café")
      result_sao = FilterPrograms.execute(programs, "são")
      result_moskva = FilterPrograms.execute(programs, "москва")
      result_ecole = FilterPrograms.execute(programs, "école")

      assert length(result_cafe) == 1
      assert length(result_sao) == 1
      assert length(result_moskva) == 1
      assert length(result_ecole) == 1
    end

    test "handles accented characters with special character normalization" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440190",
          title: "Café! & École"
        )
      ]

      # Special characters should be removed, accented characters preserved
      result = FilterPrograms.execute(programs, "café")

      assert_single_match(result, "Café! & École")
    end
  end

  describe "execute/2 - User Story 2: flexible matching behavior" do
    test "matches 'soc' in 'After School Soccer'" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440200",
          title: "After School Soccer"
        )
      ]

      result = FilterPrograms.execute(programs, "soc")

      assert_single_match(result, "After School Soccer")
    end

    test "matches 'dance' in 'Summer Dance Camp'" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440201",
          title: "Summer Dance Camp"
        )
      ]

      result = FilterPrograms.execute(programs, "dance")

      assert_single_match(result, "Summer Dance Camp")
    end

    test "matches 'flow' in 'Kids Yoga Flow'" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440202",
          title: "Kids Yoga Flow"
        )
      ]

      result = FilterPrograms.execute(programs, "flow")

      assert_single_match(result, "Kids Yoga Flow")
    end

    test "does NOT match 'ball' in 'Basketball Training' (substring)" do
      programs = [
        build(:program,
          id: "550e8400-e29b-41d4-a716-446655440203",
          title: "Basketball Training"
        )
      ]

      result = FilterPrograms.execute(programs, "ball")

      assert result == []
    end
  end
end
