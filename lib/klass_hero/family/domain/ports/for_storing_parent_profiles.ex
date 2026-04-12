defmodule KlassHero.Family.Domain.Ports.ForStoringParentProfiles do
  @moduledoc """
  Write-only port for storing parent profiles in the Family bounded context.

  Read operations have been moved to `ForQueryingParentProfiles`.

  ## Expected Return Values

  - `create_parent_profile/1` - Returns `{:ok, ParentProfile.t()}` or domain errors

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc """
  Creates a new parent profile in the repository.

  Accepts a map with parent profile attributes including identity_id (required).

  Returns:
  - `{:ok, ParentProfile.t()}` - Parent profile created successfully
  - `{:error, :duplicate_resource}` - Parent profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  @callback create_parent_profile(attrs :: map()) ::
              {:ok, term()} | {:error, :duplicate_resource | term()}
end
