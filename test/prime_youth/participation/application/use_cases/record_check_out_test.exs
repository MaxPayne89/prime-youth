defmodule PrimeYouth.Participation.Application.UseCases.RecordCheckOutTest do
  @moduledoc """
  Integration tests for RecordCheckOut use case.

  Tests check-out recording for children already checked in.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Participation.Application.UseCases.RecordCheckOut
  alias PrimeYouth.Participation.Domain.Models.ParticipationRecord

  describe "execute/1" do
    test "successfully checks out a checked-in record" do
      session = insert(:program_session_schema, status: :in_progress)
      child = insert(:child_schema)
      staff_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      record_schema =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: :checked_in,
          check_in_at: check_in_time,
          check_in_by: Ecto.UUID.generate()
        )

      assert {:ok, record} =
               RecordCheckOut.execute(%{
                 record_id: record_schema.id,
                 checked_out_by: staff_id,
                 notes: "Picked up by parent"
               })

      assert %ParticipationRecord{} = record
      assert record.id == record_schema.id
      assert record.status == :checked_out
      assert record.check_out_notes == "Picked up by parent"
      assert record.check_out_by == staff_id
      assert record.check_out_at != nil
    end

    test "checks out with nil notes when not provided" do
      session = insert(:program_session_schema, status: :in_progress)
      child = insert(:child_schema)
      staff_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      record_schema =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: :checked_in,
          check_in_at: check_in_time,
          check_in_by: Ecto.UUID.generate()
        )

      assert {:ok, record} =
               RecordCheckOut.execute(%{
                 record_id: record_schema.id,
                 checked_out_by: staff_id
               })

      assert record.check_out_notes == nil
      assert record.status == :checked_out
    end

    test "returns error when record not found" do
      non_existent_id = Ecto.UUID.generate()
      staff_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               RecordCheckOut.execute(%{
                 record_id: non_existent_id,
                 checked_out_by: staff_id
               })
    end

    test "returns error when record is in registered status" do
      session = insert(:program_session_schema, status: :in_progress)
      child = insert(:child_schema)
      staff_id = Ecto.UUID.generate()

      record_schema =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: :registered
        )

      assert {:error, :invalid_status_transition} =
               RecordCheckOut.execute(%{
                 record_id: record_schema.id,
                 checked_out_by: staff_id
               })
    end

    test "returns error when record is already checked out" do
      session = insert(:program_session_schema, status: :in_progress)
      child = insert(:child_schema)
      staff_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      record_schema =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: :checked_out,
          check_in_at: check_in_time,
          check_in_by: Ecto.UUID.generate(),
          check_out_at: DateTime.utc_now(),
          check_out_by: Ecto.UUID.generate()
        )

      assert {:error, :invalid_status_transition} =
               RecordCheckOut.execute(%{
                 record_id: record_schema.id,
                 checked_out_by: staff_id
               })
    end

    test "persists check-out to database" do
      session = insert(:program_session_schema, status: :in_progress)
      child = insert(:child_schema)
      staff_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      record_schema =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: :checked_in,
          check_in_at: check_in_time,
          check_in_by: Ecto.UUID.generate()
        )

      {:ok, record} =
        RecordCheckOut.execute(%{
          record_id: record_schema.id,
          checked_out_by: staff_id
        })

      reloaded =
        PrimeYouth.Repo.get(
          PrimeYouth.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema,
          record.id
        )

      assert reloaded.status == :checked_out
      assert reloaded.check_out_at != nil
      assert reloaded.check_out_by == staff_id
    end
  end
end
