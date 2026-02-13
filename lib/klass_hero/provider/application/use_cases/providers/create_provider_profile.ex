defmodule KlassHero.Provider.Application.UseCases.Providers.CreateProviderProfile do
  @moduledoc """
  Use case for creating a new provider profile.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])

  @doc """
  Creates a new provider profile for the given identity.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, :duplicate_resource}` if profile already exists
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- ProviderProfile.new(attrs_with_id),
         {:ok, persisted} <- @repository.create_provider_profile(attrs_with_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
