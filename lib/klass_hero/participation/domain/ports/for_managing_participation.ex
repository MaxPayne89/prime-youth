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

  @doc "Creates participation record. Returns `{:error, :duplicate_record}` on unique violation."
  @callback create(struct()) :: {:ok, struct()} | {:error, :duplicate_record | term()}

  @doc "Retrieves participation record by ID. Returns `{:error, :not_found}` if not found."
  @callback get_by_id(binary()) :: {:ok, struct()} | {:error, :not_found}

  @doc "Lists participation records for session, ordered by child name."
  @callback list_by_session(binary()) :: [struct()]

  @doc "Lists participation records for child across all sessions."
  @callback list_by_child(binary()) :: [struct()]

  @doc "Lists participation records for child within date range."
  @callback list_by_child_and_date_range(binary(), Date.t(), Date.t()) :: [struct()]

  @doc "Lists participation records for multiple children."
  @callback list_by_children([binary()]) :: [struct()]

  @doc "Lists participation records for multiple children within date range."
  @callback list_by_children_and_date_range([binary()], Date.t(), Date.t()) :: [struct()]

  @doc "Updates existing participation record. Returns `{:error, :stale_data}` on optimistic lock conflict."
  @callback update(struct()) :: {:ok, struct()} | {:error, :stale_data | :not_found | term()}

  @doc "Creates multiple participation records in a batch."
  @callback create_batch([struct()]) :: {:ok, [struct()]} | {:error, term()}
end
