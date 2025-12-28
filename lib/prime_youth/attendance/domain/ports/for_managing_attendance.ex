defmodule PrimeYouth.Attendance.Domain.Ports.ForManagingAttendance do
  @moduledoc """
  Repository port for attendance record persistence.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, record}` or `{:error, :duplicate_attendance}`
  - `get_by_id/1`, `get_by_session_and_child/2` - Returns `{:ok, record}` or `{:error, :not_found}`
  - `update/1` - Returns `{:ok, record}` or `{:error, :stale_data | :not_found}`
  - List operations - Return list of records directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc "Creates record. Returns `{:error, :duplicate_attendance}` on unique violation."
  @callback create(struct()) :: {:ok, struct()} | {:error, :duplicate_attendance | term()}

  @doc "Retrieves record by ID. Returns `{:error, :not_found}` if not found."
  @callback get_by_id(binary()) :: {:ok, struct()} | {:error, :not_found}

  @doc "Retrieves multiple records by their IDs."
  @callback get_many_by_ids([binary()]) :: [struct()]

  @doc "Retrieves record by session_id and child_id. Returns `{:error, :not_found}` if not found."
  @callback get_by_session_and_child(binary(), binary()) :: {:ok, struct()} | {:error, :not_found}

  @doc "Updates existing record. Returns `{:error, :stale_data}` on optimistic lock conflict."
  @callback update(struct()) :: {:ok, struct()} | {:error, :stale_data | :not_found | term()}

  @doc "Lists records for session, ordered by child name."
  @callback list_by_session(binary()) :: [struct()]

  @doc "Lists records for child, ordered by session_date desc."
  @callback list_by_child(binary()) :: [struct()]

  @doc "Lists records for parent, ordered by session_date desc."
  @callback list_by_parent(binary()) :: [struct()]

  @doc "Lists records for multiple sessions (batch fetch). Ordered by session_id, then child_id."
  @callback list_by_session_ids([binary()]) :: [struct()]

  @doc """
  Atomic check-in: creates or updates record in single database operation.

  Idempotent - returns success with updated record if already checked in.
  Uses upsert pattern on (session_id, child_id) unique constraint.
  """
  @callback check_in_atomic(binary(), binary(), binary(), String.t() | nil) ::
              {:ok, struct()} | {:error, term()}
end
