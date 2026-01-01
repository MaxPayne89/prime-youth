defmodule KlassHero.Identity.Application.UseCases.Providers.GetProviderByIdentity do
  @moduledoc """
  Use case for retrieving a provider profile by identity ID.

  Simple delegation to repository - no additional business logic required.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_provider_profiles])

  @doc """
  Retrieves a provider profile by identity ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` when found
  - `{:error, :not_found}` when no profile exists
  """
  def execute(identity_id) when is_binary(identity_id) do
    @repository.get_by_identity_id(identity_id)
  end
end
