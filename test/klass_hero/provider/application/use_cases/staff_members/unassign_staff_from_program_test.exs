defmodule KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgramTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram
  alias KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgram
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  describe "execute/2" do
    test "unassigns an active assignment and sets unassigned_at" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        AssignStaffToProgram.execute(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id
        })

      assert {:ok, %ProgramStaffAssignment{} = assignment} =
               UnassignStaffFromProgram.execute(program.id, staff.id)

      assert assignment.staff_member_id == staff.id
      assert assignment.program_id == program.id
      assert %DateTime{} = assignment.unassigned_at
    end

    test "returns not_found when no active assignment exists" do
      assert {:error, :not_found} =
               UnassignStaffFromProgram.execute(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "returns not_found when assignment was already unassigned" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        AssignStaffToProgram.execute(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id
        })

      assert {:ok, _} = UnassignStaffFromProgram.execute(program.id, staff.id)

      # Second unassign on same pair should return not_found (no active assignment)
      assert {:error, :not_found} = UnassignStaffFromProgram.execute(program.id, staff.id)
    end
  end
end
