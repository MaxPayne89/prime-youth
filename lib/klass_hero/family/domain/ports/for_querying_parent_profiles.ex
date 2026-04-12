defmodule KlassHero.Family.Domain.Ports.ForQueryingParentProfiles do
  @moduledoc """
  Read-only port for querying parent profiles in the Family bounded context.

  Separated from `ForStoringParentProfiles` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  @doc """
  Retrieves a parent profile by identity ID.

  Returns:
  - `{:ok, ParentProfile.t()}` - Parent profile found with matching identity_id
  - `{:error, :not_found}` - No parent profile exists for this identity_id
  """
  @callback get_by_identity_id(identity_id :: binary()) ::
              {:ok, term()} | {:error, :not_found}

  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean directly (no error tuple for simple existence check).
  """
  @callback has_profile?(identity_id :: binary()) :: boolean()

  @doc """
  Retrieves multiple parent profiles by their IDs.

  Missing or invalid IDs are silently excluded from the result.
  """
  @callback list_by_ids(parent_ids :: [binary()]) :: [term()]
end
