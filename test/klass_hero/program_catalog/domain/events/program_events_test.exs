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

  describe "program_schedule_updated/3" do
    test "creates a valid schedule updated event" do
      event =
        ProgramEvents.program_schedule_updated("program-123", %{
          meeting_days: ["Monday", "Wednesday"],
          meeting_start_time: ~T[16:00:00],
          meeting_end_time: ~T[17:30:00]
        })

      assert event.event_type == :program_schedule_updated
      assert event.aggregate_id == "program-123"
      assert event.aggregate_type == :program
      assert event.payload.program_id == "program-123"
      assert event.payload.meeting_days == ["Monday", "Wednesday"]
    end

    test "creates event with default empty payload" do
      event = ProgramEvents.program_schedule_updated("program-123")

      assert event.event_type == :program_schedule_updated
      assert event.payload.program_id == "program-123"
    end

    test "base_payload program_id wins over caller-supplied program_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{program_id: "should-be-overridden", extra: "data"}

      event = ProgramEvents.program_schedule_updated(real_id, conflicting_payload)

      assert event.payload.program_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil program_id" do
      assert_raise ArgumentError, fn ->
        ProgramEvents.program_schedule_updated(nil)
      end
    end

    test "raises for empty string program_id" do
      assert_raise ArgumentError, fn ->
        ProgramEvents.program_schedule_updated("")
      end
    end
  end
end
