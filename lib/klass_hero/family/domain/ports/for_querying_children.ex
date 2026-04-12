defmodule KlassHero.Family.Domain.Ports.ForQueryingChildren do
  @moduledoc """
  Read-only port for querying children in the Family bounded context.

  Separated from `ForStoringChildren` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Family.Domain.Models.Child

  @doc """
  Retrieves a child by their unique identifier.

  Returns:
  - `{:ok, Child.t()}` - Child found successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  """
  @callback get_by_id(binary()) :: {:ok, Child.t()} | {:error, :not_found}

  @doc """
  Lists all children for a given guardian.

  Returns list of children (may be empty).
  """
  @callback list_by_guardian(binary()) :: [Child.t()]

  @doc """
  Retrieves multiple children by their IDs.

  Returns list of children found (may be shorter than input if some IDs don't exist).
  """
  @callback list_by_ids([binary()]) :: [Child.t()]

  @doc """
  Checks if a guardian link exists between a child and a guardian.

  Returns `true` if the link exists, `false` otherwise.
  """
  @callback child_belongs_to_guardian?(binary(), binary()) :: boolean()
end
