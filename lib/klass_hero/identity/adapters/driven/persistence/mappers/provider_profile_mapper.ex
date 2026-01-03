defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper do
  @moduledoc """
  Maps between domain ProviderProfile entities and ProviderProfileSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ProviderProfileSchema → ProviderProfile (for reading from database)
  - to_schema/1: ProviderProfile → ProviderProfileSchema attributes (for creating/updating in database)
  - to_domain_list/1: [ProviderProfileSchema] → [ProviderProfile] (convenience for collections)

  The mapper is bidirectional to support both reading and writing provider profiles.

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert (conditionally included via maybe_add_id/2)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. The repository handles id explicitly when needed
  (e.g., for updates or when domain entity already has an id).
  """

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Identity.Domain.Models.ProviderProfile

  @doc """
  Converts an Ecto ProviderProfileSchema to a domain ProviderProfile entity.

  Returns the domain ProviderProfile struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.
  """
  def to_domain(%ProviderProfileSchema{} = schema) do
    %ProviderProfile{
      id: to_string(schema.id),
      identity_id: to_string(schema.identity_id),
      business_name: schema.business_name,
      description: schema.description,
      phone: schema.phone,
      website: schema.website,
      address: schema.address,
      logo_url: schema.logo_url,
      verified: schema.verified,
      verified_at: schema.verified_at,
      categories: schema.categories,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain ProviderProfile entity to ProviderProfileSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  This is used when creating or updating provider profiles in the database.
  """
  def to_schema(%ProviderProfile{} = provider_profile) do
    %{
      identity_id: provider_profile.identity_id,
      business_name: provider_profile.business_name,
      description: provider_profile.description,
      phone: provider_profile.phone,
      website: provider_profile.website,
      address: provider_profile.address,
      logo_url: provider_profile.logo_url,
      verified: provider_profile.verified,
      verified_at: provider_profile.verified_at,
      categories: provider_profile.categories
    }
    |> maybe_add_id(provider_profile.id)
  end

  @doc """
  Converts a list of ProviderProfileSchema structs to a list of domain ProviderProfile entities.

  This is a convenience function for mapping collections returned from database queries.
  """
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  defp maybe_add_id(attrs, nil), do: attrs
  defp maybe_add_id(attrs, id), do: Map.put(attrs, :id, id)
end
