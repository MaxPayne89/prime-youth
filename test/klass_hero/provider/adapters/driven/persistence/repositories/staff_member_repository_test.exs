defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepository
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepository
  alias KlassHero.Provider.Domain.Models.StaffMember

  describe "list_active_by_program/1" do
    test "returns StaffMember structs for active assignments" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id, first_name: "Coach", last_name: "Smith")

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id,
          assigned_at: DateTime.utc_now()
        })

      assert {:ok, [%StaffMember{} = member]} =
               StaffMemberRepository.list_active_by_program(program.id)

      assert member.id == to_string(staff.id)
      assert member.first_name == "Coach"
      assert member.last_name == "Smith"
    end

    test "returns empty list when no assignments exist" do
      program_id = Ecto.UUID.generate()
      assert {:ok, []} = StaffMemberRepository.list_active_by_program(program_id)
    end

    test "excludes staff whose assignment has been unassigned" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      active_staff = insert(:staff_member_schema, provider_id: provider.id, first_name: "Active")
      retired_staff = insert(:staff_member_schema, provider_id: provider.id, first_name: "Retired")

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: active_staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: retired_staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} = ProgramStaffAssignmentRepository.unassign(program.id, retired_staff.id)

      {:ok, members} = StaffMemberRepository.list_active_by_program(program.id)
      assert length(members) == 1
      assert hd(members).first_name == "Active"
    end

    test "excludes staff assigned to other programs" do
      provider = insert(:provider_profile_schema)
      viewed_program = insert(:program_schema, provider_id: provider.id)
      other_program = insert(:program_schema, provider_id: provider.id)
      own_staff = insert(:staff_member_schema, provider_id: provider.id, first_name: "Own")
      other_staff = insert(:staff_member_schema, provider_id: provider.id, first_name: "Other")

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: viewed_program.id,
          staff_member_id: own_staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: other_program.id,
          staff_member_id: other_staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, members} = StaffMemberRepository.list_active_by_program(viewed_program.id)
      assert length(members) == 1
      assert hd(members).first_name == "Own"
    end

    test "orders staff by assigned_at ascending" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      first = insert(:staff_member_schema, provider_id: provider.id, first_name: "First")
      second = insert(:staff_member_schema, provider_id: provider.id, first_name: "Second")

      earlier = DateTime.utc_now() |> DateTime.add(-60, :second)
      later = DateTime.utc_now()

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: second.id,
          assigned_at: later
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: first.id,
          assigned_at: earlier
        })

      {:ok, members} = StaffMemberRepository.list_active_by_program(program.id)
      assert Enum.map(members, & &1.first_name) == ["First", "Second"]
    end

    test "returns a staff member only once after unassign+reassign cycle" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      {:ok, _} = ProgramStaffAssignmentRepository.create(attrs)
      {:ok, _} = ProgramStaffAssignmentRepository.unassign(program.id, staff.id)
      {:ok, _} = ProgramStaffAssignmentRepository.create(attrs)

      {:ok, members} = StaffMemberRepository.list_active_by_program(program.id)
      assert length(members) == 1
      assert hd(members).id == to_string(staff.id)
    end
  end
end
