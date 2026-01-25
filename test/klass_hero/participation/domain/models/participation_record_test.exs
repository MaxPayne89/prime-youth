defmodule KlassHero.Participation.Domain.Models.ParticipationRecordTest do
  @moduledoc """
  Tests for ParticipationRecord domain entity.

  Covers validation, status transitions, and check-in/out flows.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  describe "new/1" do
    test "creates a valid participation record with required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate()
      }

      assert {:ok, record} = ParticipationRecord.new(attrs)
      assert record.id == attrs.id
      assert record.session_id == attrs.session_id
      assert record.child_id == attrs.child_id
      assert record.status == :registered
      assert record.lock_version == 1
    end

    test "creates record with optional fields" do
      parent_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: parent_id,
        provider_id: provider_id
      }

      assert {:ok, record} = ParticipationRecord.new(attrs)
      assert record.parent_id == parent_id
      assert record.provider_id == provider_id
    end

    test "returns error when id is missing" do
      attrs = %{
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate()
      }

      assert {:error, :missing_required_fields} = ParticipationRecord.new(attrs)
    end

    test "returns error when session_id is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate()
      }

      assert {:error, :missing_required_fields} = ParticipationRecord.new(attrs)
    end

    test "returns error when child_id is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate()
      }

      assert {:error, :missing_required_fields} = ParticipationRecord.new(attrs)
    end
  end

  describe "check_in/3" do
    test "transitions :registered record to :checked_in" do
      record = build(:participation_record, status: :registered)
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_in} =
               ParticipationRecord.check_in(record, provider_id, "Arrived early")

      assert checked_in.status == :checked_in
      assert checked_in.check_in_by == provider_id
      assert checked_in.check_in_notes == "Arrived early"
      assert %DateTime{} = checked_in.check_in_at
    end

    test "allows nil notes" do
      record = build(:participation_record, status: :registered)
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_in} = ParticipationRecord.check_in(record, provider_id)

      assert checked_in.check_in_notes == nil
    end

    test "returns error when checking in already checked-in record" do
      record = build(:participation_record, status: :checked_in)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_in(record, provider_id)
    end

    test "returns error when checking in checked-out record" do
      record = build(:participation_record, status: :checked_out)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_in(record, provider_id)
    end

    test "returns error when checking in absent record" do
      record = build(:participation_record, status: :absent)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_in(record, provider_id)
    end
  end

  describe "check_out/3" do
    test "transitions :checked_in record to :checked_out" do
      record =
        build(:participation_record,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_out} =
               ParticipationRecord.check_out(record, provider_id, "Picked up by mom")

      assert checked_out.status == :checked_out
      assert checked_out.check_out_by == provider_id
      assert checked_out.check_out_notes == "Picked up by mom"
      assert %DateTime{} = checked_out.check_out_at
    end

    test "allows nil notes" do
      record =
        build(:participation_record,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_out} = ParticipationRecord.check_out(record, provider_id)

      assert checked_out.check_out_notes == nil
    end

    test "returns error when checking out :registered record" do
      record = build(:participation_record, status: :registered)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_out(record, provider_id)
    end

    test "returns error when checking out already checked-out record" do
      record = build(:participation_record, status: :checked_out)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_out(record, provider_id)
    end

    test "returns error when checking out absent record" do
      record = build(:participation_record, status: :absent)
      provider_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               ParticipationRecord.check_out(record, provider_id)
    end
  end

  describe "mark_absent/1" do
    test "transitions :registered record to :absent" do
      record = build(:participation_record, status: :registered)

      assert {:ok, absent} = ParticipationRecord.mark_absent(record)
      assert absent.status == :absent
    end

    test "returns error when marking :checked_in as absent" do
      record = build(:participation_record, status: :checked_in)

      assert {:error, :invalid_status_transition} = ParticipationRecord.mark_absent(record)
    end

    test "returns error when marking :checked_out as absent" do
      record = build(:participation_record, status: :checked_out)

      assert {:error, :invalid_status_transition} = ParticipationRecord.mark_absent(record)
    end

    test "returns error when marking :absent as absent" do
      record = build(:participation_record, status: :absent)

      assert {:error, :invalid_status_transition} = ParticipationRecord.mark_absent(record)
    end
  end

  describe "checked_in?/1" do
    test "returns true for :checked_in status" do
      record = build(:participation_record, status: :checked_in)
      assert ParticipationRecord.checked_in?(record)
    end

    test "returns false for :registered status" do
      record = build(:participation_record, status: :registered)
      refute ParticipationRecord.checked_in?(record)
    end

    test "returns false for :checked_out status" do
      record = build(:participation_record, status: :checked_out)
      refute ParticipationRecord.checked_in?(record)
    end

    test "returns false for :absent status" do
      record = build(:participation_record, status: :absent)
      refute ParticipationRecord.checked_in?(record)
    end
  end

  describe "completed?/1" do
    test "returns true for :checked_out status" do
      record = build(:participation_record, status: :checked_out)
      assert ParticipationRecord.completed?(record)
    end

    test "returns false for :registered status" do
      record = build(:participation_record, status: :registered)
      refute ParticipationRecord.completed?(record)
    end

    test "returns false for :checked_in status" do
      record = build(:participation_record, status: :checked_in)
      refute ParticipationRecord.completed?(record)
    end

    test "returns false for :absent status" do
      record = build(:participation_record, status: :absent)
      refute ParticipationRecord.completed?(record)
    end
  end

  describe "valid_statuses/0" do
    test "returns list of valid status atoms" do
      statuses = ParticipationRecord.valid_statuses()

      assert :registered in statuses
      assert :checked_in in statuses
      assert :checked_out in statuses
      assert :absent in statuses
      assert length(statuses) == 4
    end
  end
end
