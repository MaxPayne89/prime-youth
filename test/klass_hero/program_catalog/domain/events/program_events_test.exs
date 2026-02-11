defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramEventsTest do
  @moduledoc """
  Tests for ProgramEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents

  describe "program_created/3" do
    test "base_payload program_id wins over caller-supplied program_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{program_id: "should-be-overridden", extra: "data"}

      event = ProgramEvents.program_created(real_id, conflicting_payload)

      assert event.payload.program_id == real_id
      assert event.payload.extra == "data"
    end

    test "creates event with correct type" do
      program_id = Ecto.UUID.generate()

      event = ProgramEvents.program_created(program_id)

      assert event.event_type == :program_created
      assert event.aggregate_id == program_id
    end

    test "raises for nil program_id" do
      assert_raise ArgumentError, fn ->
        ProgramEvents.program_created(nil)
      end
    end

    test "raises for empty string program_id" do
      assert_raise ArgumentError, fn ->
        ProgramEvents.program_created("")
      end
    end
  end
end
