defmodule PrimeYouth.Identity.Application.UseCases.Parents.GetParentByIdentity do
  @moduledoc """
  Use case for retrieving a parent profile by identity ID.

  Simple delegation to repository - no additional business logic required.
  """

  @repository Application.compile_env!(:prime_youth, [:identity, :for_storing_parent_profiles])

  @doc """
  Retrieves a parent profile by identity ID.

  Returns:
  - `{:ok, ParentProfile.t()}` when found
  - `{:error, :not_found}` when no profile exists
  """
  def execute(identity_id) when is_binary(identity_id) do
    @repository.get_by_identity_id(identity_id)
  end
end
