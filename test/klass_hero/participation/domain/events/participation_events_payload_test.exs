defmodule KlassHero.Participation.Domain.Events.ParticipationEventsPayloadTest do
  use ExUnit.Case, async: true

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

  @program_id Ecto.UUID.generate()

  defp build_record do
    %ParticipationRecord{
      id: Ecto.UUID.generate(),
      session_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      status: :checked_in,
      check_in_by: Ecto.UUID.generate(),
      check_in_at: DateTime.utc_now(),
      check_in_notes: nil
    }
  end

  defp build_session do
    %ProgramSession{
      id: Ecto.UUID.generate(),
      program_id: @program_id,
      session_date: Date.utc_today(),
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      status: :in_progress
    }
  end

  describe "child_checked_in/2 with session" do
    test "includes program_id from session in payload" do
      record = build_record()
      session = build_session()

      event = ParticipationEvents.child_checked_in(record, session)

      assert event.payload.program_id == @program_id
    end

    test "preserves all existing payload fields" do
      record = build_record()
      session = build_session()

      event = ParticipationEvents.child_checked_in(record, session)

      assert event.payload.record_id == record.id
      assert event.payload.session_id == record.session_id
      assert event.payload.child_id == record.child_id
    end
  end

  describe "child_checked_out/2 with session" do
    test "includes program_id from session in payload" do
      record = %{
        build_record()
        | status: :checked_out,
          check_out_by: Ecto.UUID.generate(),
          check_out_at: DateTime.utc_now()
      }

      session = build_session()

      event = ParticipationEvents.child_checked_out(record, session)

      assert event.payload.program_id == @program_id
    end
  end

  describe "child_marked_absent/2 with session" do
    test "includes program_id from session in payload" do
      record = %{build_record() | status: :absent}
      session = build_session()

      event = ParticipationEvents.child_marked_absent(record, session)

      assert event.payload.program_id == @program_id
    end
  end
end
