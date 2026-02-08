defmodule KlassHero.Identity.Application.UseCases.Providers.UpdateProviderProfile do
  @moduledoc """
  Use case for updating an existing provider profile.

  Loads the provider, merges updated fields into the domain struct,
  validates at the domain level, then persists via the repository port.
  """

  alias KlassHero.Identity.Domain.Models.ProviderProfile

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_provider_profiles])

  @doc """
  Updates an existing provider profile with the given attributes.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :not_found}` if provider doesn't exist
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(provider_id, attrs) when is_binary(provider_id) and is_map(attrs) do
    with {:ok, existing} <- @repository.get(provider_id),
         merged = Map.merge(Map.from_struct(existing), attrs),
         {:ok, _validated} <- ProviderProfile.new(merged),
         # Trigger: domain validation passed, now persist
         # Why: we update the existing struct (not the validated one) with new attrs
         #      to preserve fields that ProviderProfile.new/1 might reset (timestamps)
         updated = struct(existing, attrs),
         {:ok, persisted} <- @repository.update(updated) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
