defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProgramStaffAssignmentMapperTest do
  @moduledoc """
  Unit tests for ProgramStaffAssignmentMapper.

  Covers schema-to-domain mapping including UUID string conversion,
  active vs unassigned state, and timestamp preservation.
  No database required.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProgramStaffAssignmentMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @id Ecto.UUID.generate()
  @provider_id Ecto.UUID.generate()
  @program_id Ecto.UUID.generate()
  @staff_member_id Ecto.UUID.generate()
  @assigned_at ~U[2025-03-01 08:00:00.000000Z]

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: @id,
      provider_id: @provider_id,
      program_id: @program_id,
      staff_member_id: @staff_member_id,
      assigned_at: @assigned_at,
      unassigned_at: nil,
      inserted_at: ~U[2025-03-01 08:00:00.000000Z],
      updated_at: ~U[2025-03-02 08:00:00.000000Z]
    }

    struct!(ProgramStaffAssignmentSchema, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "maps all fields from schema to domain struct" do
      schema = valid_schema()

      assignment = ProgramStaffAssignmentMapper.to_domain(schema)

      assert %ProgramStaffAssignment{} = assignment
      assert assignment.id == @id
      assert assignment.provider_id == @provider_id
      assert assignment.program_id == @program_id
      assert assignment.staff_member_id == @staff_member_id
      assert assignment.assigned_at == @assigned_at
      assert assignment.unassigned_at == nil
    end

    test "converts UUID binary fields to strings" do
      schema = valid_schema()

      assignment = ProgramStaffAssignmentMapper.to_domain(schema)

      assert is_binary(assignment.id)
      assert is_binary(assignment.provider_id)
      assert is_binary(assignment.program_id)
      assert is_binary(assignment.staff_member_id)
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      assignment = ProgramStaffAssignmentMapper.to_domain(schema)

      assert assignment.inserted_at == ~U[2025-03-01 08:00:00.000000Z]
      assert assignment.updated_at == ~U[2025-03-02 08:00:00.000000Z]
    end

    test "maps active assignment (unassigned_at nil)" do
      schema = valid_schema(%{unassigned_at: nil})

      assignment = ProgramStaffAssignmentMapper.to_domain(schema)

      assert assignment.unassigned_at == nil
      assert ProgramStaffAssignment.active?(assignment) == true
    end

    test "maps unassigned assignment with unassigned_at timestamp" do
      unassigned_at = ~U[2025-06-01 12:00:00.000000Z]
      schema = valid_schema(%{unassigned_at: unassigned_at})

      assignment = ProgramStaffAssignmentMapper.to_domain(schema)

      assert assignment.unassigned_at == unassigned_at
      assert ProgramStaffAssignment.active?(assignment) == false
    end
  end
end
