defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepository
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  describe "create/1" do
    test "creates an active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      assert {:ok, %ProgramStaffAssignment{} = assignment} =
               ProgramStaffAssignmentRepository.create(attrs)

      assert assignment.provider_id == to_string(provider.id)
      assert assignment.program_id == to_string(program.id)
      assert assignment.staff_member_id == to_string(staff.id)
      assert is_nil(assignment.unassigned_at)
    end

    test "returns already_assigned for duplicate active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      assert {:ok, _} = ProgramStaffAssignmentRepository.create(attrs)
      assert {:error, :already_assigned} = ProgramStaffAssignmentRepository.create(attrs)
    end

    test "allows re-assignment after unassign" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      assert {:ok, _} = ProgramStaffAssignmentRepository.create(attrs)
      assert {:ok, _} = ProgramStaffAssignmentRepository.unassign(program.id, staff.id)
      assert {:ok, new_assignment} = ProgramStaffAssignmentRepository.create(attrs)
      assert is_nil(new_assignment.unassigned_at)
    end
  end

  describe "unassign/2" do
    test "sets unassigned_at on active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id,
          assigned_at: DateTime.utc_now()
        })

      assert {:ok, %ProgramStaffAssignment{unassigned_at: unassigned_at}} =
               ProgramStaffAssignmentRepository.unassign(program.id, staff.id)

      refute is_nil(unassigned_at)
    end

    test "returns not_found for non-existent assignment" do
      assert {:error, :not_found} =
               ProgramStaffAssignmentRepository.unassign(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate()
               )
    end
  end

  describe "list_active_for_program/1" do
    test "returns only active assignments for program" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff1 = insert(:staff_member_schema, provider_id: provider.id)
      staff2 = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff1.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff2.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} = ProgramStaffAssignmentRepository.unassign(program.id, staff2.id)

      active = ProgramStaffAssignmentRepository.list_active_for_program(program.id)
      assert length(active) == 1
      assert hd(active).staff_member_id == to_string(staff1.id)
    end

    test "returns empty list when no active assignments exist" do
      program_id = Ecto.UUID.generate()
      assert [] = ProgramStaffAssignmentRepository.list_active_for_program(program_id)
    end
  end

  describe "list_active_for_staff_member/1" do
    test "returns only active assignments for a staff member" do
      provider = insert(:provider_profile_schema)
      program1 = insert(:program_schema, provider_id: provider.id)
      program2 = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program1.id,
          staff_member_id: staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program2.id,
          staff_member_id: staff.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} = ProgramStaffAssignmentRepository.unassign(program2.id, staff.id)

      active = ProgramStaffAssignmentRepository.list_active_for_staff_member(staff.id)
      assert length(active) == 1
      assert hd(active).program_id == to_string(program1.id)
    end
  end

  describe "list_active_for_provider/1" do
    test "returns all active assignments for a provider" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff1 = insert(:staff_member_schema, provider_id: provider.id)
      staff2 = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff1.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff2.id,
          assigned_at: DateTime.utc_now()
        })

      active = ProgramStaffAssignmentRepository.list_active_for_provider(provider.id)
      assert length(active) == 2
    end

    test "does not return assignments from another provider" do
      provider1 = insert(:provider_profile_schema)
      provider2 = insert(:provider_profile_schema)
      program1 = insert(:program_schema, provider_id: provider1.id)
      program2 = insert(:program_schema, provider_id: provider2.id)
      staff1 = insert(:staff_member_schema, provider_id: provider1.id)
      staff2 = insert(:staff_member_schema, provider_id: provider2.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider1.id,
          program_id: program1.id,
          staff_member_id: staff1.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider2.id,
          program_id: program2.id,
          staff_member_id: staff2.id,
          assigned_at: DateTime.utc_now()
        })

      active = ProgramStaffAssignmentRepository.list_active_for_provider(provider1.id)
      assert length(active) == 1
      assert hd(active).provider_id == to_string(provider1.id)
    end
  end
end
