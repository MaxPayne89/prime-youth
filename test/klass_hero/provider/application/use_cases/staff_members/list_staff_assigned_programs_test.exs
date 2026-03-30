defmodule KlassHero.Provider.Application.UseCases.StaffMembers.ListStaffAssignedProgramsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.ProviderFixtures

  alias KlassHero.Provider.Application.UseCases.StaffMembers.ListStaffAssignedPrograms

  describe "execute/2" do
    test "returns all programs when staff has no tags" do
      staff = staff_member_fixture(%{tags: []})
      programs = [%{category: "sports"}, %{category: "arts"}]

      result = ListStaffAssignedPrograms.execute(staff, programs)
      assert length(result) == 2
    end

    test "filters programs by staff tags" do
      staff = staff_member_fixture(%{tags: ["sports"]})
      programs = [%{category: "sports"}, %{category: "arts"}, %{category: "music"}]

      result = ListStaffAssignedPrograms.execute(staff, programs)
      assert length(result) == 1
      assert hd(result).category == "sports"
    end

    test "returns empty list when no programs match" do
      staff = staff_member_fixture(%{tags: ["music"]})
      programs = [%{category: "sports"}, %{category: "arts"}]

      assert ListStaffAssignedPrograms.execute(staff, programs) == []
    end

    test "returns empty list when programs list is empty" do
      staff = staff_member_fixture(%{tags: ["sports"]})

      assert ListStaffAssignedPrograms.execute(staff, []) == []
    end
  end
end
