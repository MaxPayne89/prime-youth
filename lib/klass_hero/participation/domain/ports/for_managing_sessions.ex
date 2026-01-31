defmodule KlassHero.Participation.Domain.Ports.ForManagingSessions do
  @moduledoc """
  Repository port for session persistence.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, session}` or `{:error, :duplicate_session}`
  - `get_by_id/1` - Returns `{:ok, session}` or `{:error, :not_found}`
  - `update/1` - Returns `{:ok, session}` or `{:error, :stale_data | :not_found}`
  - List operations - Return list of sessions directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Participation.Domain.Models.ProgramSession

  @doc "Creates session. Returns `{:error, :duplicate_session}` on unique violation."
  @callback create(ProgramSession.t()) ::
              {:ok, ProgramSession.t()} | {:error, :duplicate_session | :validation_failed}

  @doc "Retrieves session by ID. Returns `{:error, :not_found}` if not found."
  @callback get_by_id(binary()) :: {:ok, ProgramSession.t()} | {:error, :not_found}

  @doc "Lists sessions for program, ordered by session_date, then start_time."
  @callback list_by_program(binary()) :: [ProgramSession.t()]

  @doc "Lists sessions for date, ordered by start_time."
  @callback list_today_sessions(Date.t()) :: [ProgramSession.t()]

  @doc "Updates existing session. Returns `{:error, :stale_data}` on optimistic lock conflict."
  @callback update(ProgramSession.t()) ::
              {:ok, ProgramSession.t()} | {:error, :stale_data | :not_found | :validation_failed}

  @doc """
  Lists sessions for a provider on a specific date, ordered by start_time.

  Note: Requires provider-program relationship in schema for full filtering.
  Currently filters by date only until schema is updated.
  """
  @callback list_by_provider_and_date(binary(), Date.t()) :: [ProgramSession.t()]

  @doc "Retrieves multiple sessions by their IDs (batch fetch)."
  @callback get_many_by_ids([binary()]) :: [ProgramSession.t()]
end
