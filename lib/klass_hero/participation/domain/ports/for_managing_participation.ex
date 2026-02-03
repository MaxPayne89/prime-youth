defmodule KlassHero.Participation.Domain.Ports.ForManagingParticipation do
  @moduledoc """
  Repository port for participation record persistence.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, record}` or `{:error, :duplicate_record}`
  - `get_by_id/1` - Returns `{:ok, record}` or `{:error, :not_found}`
  - `update/1` - Returns `{:ok, record}` or `{:error, :stale_data | :not_found}`
  - List operations - Return list of records directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @doc "Creates participation record. Returns `{:error, :duplicate_record}` on unique violation."
  @callback create(ParticipationRecord.t()) ::
              {:ok, ParticipationRecord.t()} | {:error, :duplicate_record | :validation_failed}

  @doc "Retrieves participation record by ID. Returns `{:error, :not_found}` if not found."
  @callback get_by_id(binary()) :: {:ok, ParticipationRecord.t()} | {:error, :not_found}

  @doc "Lists participation records for session, ordered by child name."
  @callback list_by_session(binary()) :: [ParticipationRecord.t()]

  @doc "Lists participation records for child across all sessions."
  @callback list_by_child(binary()) :: [ParticipationRecord.t()]

  @doc "Lists participation records for child within date range."
  @callback list_by_child_and_date_range(binary(), Date.t(), Date.t()) :: [
              ParticipationRecord.t()
            ]

  @doc "Lists participation records for multiple children."
  @callback list_by_children([binary()]) :: [ParticipationRecord.t()]

  @doc "Lists participation records for multiple children within date range."
  @callback list_by_children_and_date_range([binary()], Date.t(), Date.t()) :: [
              ParticipationRecord.t()
            ]

  @doc "Updates existing participation record. Returns `{:error, :stale_data}` on optimistic lock conflict."
  @callback update(ParticipationRecord.t()) ::
              {:ok, ParticipationRecord.t()}
              | {:error, :stale_data | :not_found | :validation_failed}

  @doc "Creates multiple participation records in a batch."
  @callback create_batch([ParticipationRecord.t()]) ::
              {:ok, [ParticipationRecord.t()]} | {:error, :validation_failed}
end
