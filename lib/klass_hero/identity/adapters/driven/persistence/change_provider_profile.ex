defmodule KlassHero.Identity.Adapters.Driven.Persistence.ChangeProviderProfile do
  @moduledoc """
  Adapter for building provider profile form changesets.

  Converts domain ProviderProfile structs to persistence schemas and produces
  changesets for LiveView form tracking. Lives in the adapter layer because it
  depends on the Ecto schema (ProviderProfileSchema).
  """

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Identity.Domain.Models.ProviderProfile

  @doc """
  Returns a changeset for provider profile form tracking.

  Accepts a `%ProviderProfile{}` domain struct and an optional attributes map.
  """
  def execute(%ProviderProfile{} = provider, attrs \\ %{}) do
    provider |> provider_to_schema() |> ProviderProfileSchema.edit_changeset(attrs)
  end

  defp provider_to_schema(%ProviderProfile{} = provider) do
    %ProviderProfileSchema{
      id: provider.id,
      identity_id: provider.identity_id,
      business_name: provider.business_name,
      description: provider.description,
      phone: provider.phone,
      website: provider.website,
      address: provider.address,
      logo_url: provider.logo_url,
      verified: provider.verified,
      verified_at: provider.verified_at,
      verified_by_id: provider.verified_by_id,
      categories: provider.categories,
      subscription_tier:
        if(is_atom(provider.subscription_tier),
          do: to_string(provider.subscription_tier),
          else: provider.subscription_tier
        )
    }
  end
end
