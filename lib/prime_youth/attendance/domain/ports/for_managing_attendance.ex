defmodule PrimeYouth.Attendance.Domain.Ports.ForManagingAttendance do
  @moduledoc """
  Repository port for attendance record persistence.

  ## Error Types

  - `:database_connection_error`, `:database_query_error`, `:database_unavailable`
  - `:not_found`, `:duplicate_attendance` (unique: session_id + child_id)
  """

  @doc "Creates record. Unique constraint: one record per session/child combination."
  @callback create(struct()) :: {:ok, struct()} | {:error, atom()}

  @doc "Retrieves record by ID."
  @callback get_by_id(binary()) :: {:ok, struct()} | {:error, atom()}

  @doc "Retrieves multiple records by their IDs."
  @callback get_many_by_ids([binary()]) :: {:ok, [struct()]} | {:error, atom()}

  @doc "Retrieves record by session_id and child_id."
  @callback get_by_session_and_child(binary(), binary()) :: {:ok, struct()} | {:error, atom()}

  @doc "Updates existing record atomically."
  @callback update(struct()) :: {:ok, struct()} | {:error, atom()}

  @doc "Lists records for session, ordered by child name."
  @callback list_by_session(binary()) :: {:ok, [struct()]} | {:error, atom()}

  @doc "Lists records for child, ordered by session_date desc."
  @callback list_by_child(binary()) :: {:ok, [struct()]} | {:error, atom()}

  @doc "Lists records for parent, ordered by session_date desc."
  @callback list_by_parent(binary()) :: {:ok, [struct()]} | {:error, atom()}

  @doc """
  Submits batch of records for payroll (atomic operation).

  All records must belong to session, have submittable status, and not be already submitted.
  """
  @callback submit_batch(binary(), [struct()], binary()) :: {:ok, [struct()]} | {:error, atom()}
end
