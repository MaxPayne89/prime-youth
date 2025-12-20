defmodule PrimeYouth.Attendance.Domain.Ports.ForManagingSessions do
  @moduledoc """
  Repository port for session persistence.

  ## Error Types

  - `:database_connection_error`, `:database_query_error`, `:database_unavailable`
  - `:not_found`, `:duplicate_session` (unique: program_id + session_date + start_time)
  """

  @doc "Creates session. Unique constraint: one session per program/date/start_time combination."
  @callback create(struct()) :: {:ok, struct()} | {:error, atom()}

  @doc "Retrieves session by ID."
  @callback get_by_id(binary()) :: {:ok, struct()} | {:error, atom()}

  @doc "Lists sessions for program, ordered by session_date, then start_time."
  @callback list_by_program(binary()) :: {:ok, [struct()]} | {:error, atom()}

  @doc "Lists sessions for date, ordered by start_time."
  @callback list_today_sessions(Date.t()) :: {:ok, [struct()]} | {:error, atom()}

  @doc "Updates existing session atomically."
  @callback update(struct()) :: {:ok, struct()} | {:error, atom()}
end
