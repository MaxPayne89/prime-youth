defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema do
  @moduledoc """
  Ecto schema for the attendance_records table.

  Use AttendanceRecordMapper for domain entity conversion.
  Includes optimistic locking via lock_version.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "attendance_records" do
    field :session_id, :binary_id
    field :child_id, :binary_id
    field :parent_id, :binary_id
    field :provider_id, :binary_id
    field :status, :string
    field :check_in_at, :utc_datetime
    field :check_in_notes, :string
    field :check_in_by, :binary_id
    field :check_out_at, :utc_datetime
    field :check_out_notes, :string
    field :check_out_by, :binary_id
    field :lock_version, :integer, default: 1

    timestamps()
  end

  def changeset(attendance_record_schema, attrs) do
    attendance_record_schema
    |> cast(attrs, [
      :session_id,
      :child_id,
      :parent_id,
      :provider_id,
      :status,
      :check_in_at,
      :check_in_notes,
      :check_in_by,
      :check_out_at,
      :check_out_notes,
      :check_out_by
    ])
    |> validate_required([
      :session_id,
      :child_id,
      :status
    ])
    |> validate_inclusion(:status, ["expected", "checked_in", "checked_out", "absent", "excused"])
    |> unique_constraint([:session_id, :child_id],
      name: :attendance_records_session_id_child_id_index,
      message: "attendance record already exists for this child in this session"
    )
    |> check_constraint(:check_out_at,
      name: :check_out_after_check_in,
      message: "check out time must be after check in time"
    )
  end

  @doc """
  Update changeset with optimistic locking.

  Will fail with Ecto.StaleEntryError if the record was modified
  by another process since it was loaded.
  """
  def update_changeset(attendance_record_schema, attrs) do
    attendance_record_schema
    |> cast(attrs, [
      :session_id,
      :child_id,
      :parent_id,
      :provider_id,
      :status,
      :check_in_at,
      :check_in_notes,
      :check_in_by,
      :check_out_at,
      :check_out_notes,
      :check_out_by
    ])
    |> validate_required([
      :session_id,
      :child_id,
      :status
    ])
    |> validate_inclusion(:status, ["expected", "checked_in", "checked_out", "absent", "excused"])
    |> unique_constraint([:session_id, :child_id],
      name: :attendance_records_session_id_child_id_index,
      message: "attendance record already exists for this child in this session"
    )
    |> check_constraint(:check_out_at,
      name: :check_out_after_check_in,
      message: "check out time must be after check in time"
    )
    |> optimistic_lock(:lock_version)
  end
end
