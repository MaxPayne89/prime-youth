defmodule KlassHero.Provider.Domain.Services.StaffProgramFilterTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Services.StaffProgramFilter

  describe "filter_by_tags/2" do
    test "returns all programs when tags list is empty" do
      programs = [%{category: "sports"}, %{category: "arts"}]
      assert StaffProgramFilter.filter_by_tags(programs, []) == programs
    end

    test "filters programs by category matching tags" do
      programs = [%{category: "sports"}, %{category: "arts"}, %{category: "music"}]
      result = StaffProgramFilter.filter_by_tags(programs, ["sports", "music"])

      assert length(result) == 2
      assert Enum.all?(result, &(&1.category in ["sports", "music"]))
    end

    test "returns empty list when no programs match tags" do
      programs = [%{category: "sports"}, %{category: "arts"}]
      assert StaffProgramFilter.filter_by_tags(programs, ["music"]) == []
    end

    test "handles empty programs list" do
      assert StaffProgramFilter.filter_by_tags([], ["sports"]) == []
    end

    test "handles single matching tag" do
      programs = [%{category: "sports"}, %{category: "arts"}]
      result = StaffProgramFilter.filter_by_tags(programs, ["sports"])

      assert [%{category: "sports"}] = result
    end
  end
end
