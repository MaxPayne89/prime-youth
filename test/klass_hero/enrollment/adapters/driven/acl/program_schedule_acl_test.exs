defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ProgramScheduleACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.ACL.ProgramScheduleACL

  describe "get_program_start_date/1" do
    test "returns the start date for a program with a start date" do
      program = insert(:program_schema, start_date: ~D[2026-03-01])

      assert {:ok, ~D[2026-03-01]} = ProgramScheduleACL.get_program_start_date(program.id)
    end

    test "returns nil for a program without a start date" do
      program = insert(:program_schema, start_date: nil)

      assert {:ok, nil} = ProgramScheduleACL.get_program_start_date(program.id)
    end

    test "returns error when program does not exist" do
      assert {:error, :not_found} =
               ProgramScheduleACL.get_program_start_date(Ecto.UUID.generate())
    end
  end
end
