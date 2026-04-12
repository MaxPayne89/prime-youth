defmodule KlassHero.Family.Application.Queries.Parents.ParentProfileQueries do
  @moduledoc """
  Queries for parent profile read operations.
  """

  @parent_repository Application.compile_env!(:klass_hero, [
                       :family,
                       :for_querying_parent_profiles
                     ])

  @doc """
  Retrieves a parent profile by identity ID.

  Returns:
  - `{:ok, ParentProfile.t()}` - Parent profile found
  - `{:error, :not_found}` - No parent profile exists
  """
  def get_by_identity(identity_id) do
    @parent_repository.get_by_identity_id(identity_id)
  end

  @doc """
  Checks if a parent profile exists for the given identity ID.
  """
  @spec has_profile?(binary()) :: boolean()
  def has_profile?(identity_id) do
    @parent_repository.has_profile?(identity_id)
  end

  @doc """
  Retrieves multiple parent profiles by their IDs.

  Missing or invalid IDs are silently excluded from the result.
  """
  def get_by_ids(parent_ids) do
    @parent_repository.list_by_ids(parent_ids)
  end
end
