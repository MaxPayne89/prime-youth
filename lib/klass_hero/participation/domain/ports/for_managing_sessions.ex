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

  @doc "Retrieves the program name for a given program ID. Returns nil if not found."
  @callback get_program_name(binary()) :: String.t() | nil

  @type admin_filter :: %{
          optional(:date) => Date.t(),
          optional(:date_from) => Date.t(),
          optional(:date_to) => Date.t(),
          optional(:provider_id) => String.t(),
          optional(:program_id) => String.t(),
          optional(:status) => ProgramSession.status()
        }

  @type admin_session :: %{
          id: String.t(),
          program_id: String.t(),
          program_name: String.t(),
          provider_name: String.t(),
          session_date: Date.t(),
          start_time: Time.t(),
          end_time: Time.t(),
          status: ProgramSession.status(),
          checked_in_count: non_neg_integer(),
          total_count: non_neg_integer()
        }

  @doc "Lists sessions with enriched data for admin dashboard."
  @callback list_admin_sessions(admin_filter()) :: [admin_session()]
end
