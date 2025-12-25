defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Mappers.AttendanceRecordMapper do
  @moduledoc """
  Bidirectional mapping between AttendanceRecord domain entities and AttendanceRecordSchema.

  This adapter provides bidirectional conversion:
  - to_domain/1: AttendanceRecordSchema → AttendanceRecord (for reading from database)
  - to_schema/1: AttendanceRecord → AttendanceRecordSchema attributes (for creating/updating)
  - to_domain_list/1: [AttendanceRecordSchema] → [AttendanceRecord] (convenience for collections)

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert
  - `lock_version` - Managed by optimistic locking (see AttendanceRepository.update/1)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. Repositories handle id/lock_version explicitly
  when needed (e.g., optimistic locking in updates).
  """

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  @valid_statuses ~w(expected checked_in checked_out absent excused)a

  def to_domain(%AttendanceRecordSchema{} = schema) do
    %AttendanceRecord{
      id: to_string(schema.id),
      session_id: to_string(schema.session_id),
      child_id: to_string(schema.child_id),
      parent_id: to_string_or_nil(schema.parent_id),
      provider_id: to_string_or_nil(schema.provider_id),
      status: parse_status(schema.status),
      check_in_at: schema.check_in_at,
      check_in_notes: schema.check_in_notes,
      check_in_by: to_string_or_nil(schema.check_in_by),
      check_out_at: schema.check_out_at,
      check_out_notes: schema.check_out_notes,
      check_out_by: to_string_or_nil(schema.check_out_by),
      submitted: schema.submitted,
      submitted_at: schema.submitted_at,
      submitted_by: to_string_or_nil(schema.submitted_by),
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at,
      lock_version: schema.lock_version
    }
  end

  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  @doc """
  Converts domain entity to schema attributes for insert/update.

  Excludes id, timestamps, and lock_version (managed by Ecto).
  UUIDs are passed as strings - Ecto's :binary_id handles the conversion.
  """
  def to_schema(%AttendanceRecord{} = record) do
    %{
      session_id: record.session_id,
      child_id: record.child_id,
      parent_id: record.parent_id,
      provider_id: record.provider_id,
      status: Atom.to_string(record.status),
      check_in_at: record.check_in_at,
      check_in_notes: record.check_in_notes,
      check_in_by: record.check_in_by,
      check_out_at: record.check_out_at,
      check_out_notes: record.check_out_notes,
      check_out_by: record.check_out_by,
      submitted: record.submitted,
      submitted_at: record.submitted_at,
      submitted_by: record.submitted_by
    }
  end

  defp to_string_or_nil(nil), do: nil

  defp to_string_or_nil(binary_uuid) when is_binary(binary_uuid) do
    case Ecto.UUID.cast(binary_uuid) do
      {:ok, string_uuid} -> string_uuid
      :error -> to_string(binary_uuid)
    end
  end

  defp parse_status(status) when is_binary(status) do
    atom = String.to_atom(status)
    if atom in @valid_statuses, do: atom, else: :expected
  end

  defp parse_status(status) when is_atom(status), do: status
end
