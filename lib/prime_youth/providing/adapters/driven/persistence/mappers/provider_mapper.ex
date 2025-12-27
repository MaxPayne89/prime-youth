defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Mappers.ProviderMapper do
  @moduledoc """
  Maps between domain Provider entities and ProviderSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ProviderSchema → Provider (for reading from database)
  - to_schema/1: Provider → ProviderSchema attributes (for creating/updating in database)
  - to_domain_list/1: [ProviderSchema] → [Provider] (convenience for collections)

  The mapper is bidirectional to support both reading and writing provider profiles.

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert (conditionally included via maybe_add_id/2)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. The repository handles id explicitly when needed
  (e.g., for updates or when domain entity already has an id).
  """

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema
  alias PrimeYouth.Providing.Domain.Models.Provider

  @doc """
  Converts an Ecto ProviderSchema to a domain Provider entity.

  Returns the domain Provider struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.

  ## Examples

      iex> schema = %ProviderSchema{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   business_name: "Kids Sports Academy",
      ...>   description: "Youth sports training",
      ...>   phone: "+1234567890",
      ...>   website: "https://example.com",
      ...>   address: "123 Sports Lane",
      ...>   logo_url: "https://example.com/logo.png",
      ...>   verified: true,
      ...>   verified_at: ~U[2025-01-15 10:00:00Z],
      ...>   categories: ["sports", "outdoor"],
      ...>   inserted_at: ~U[2025-12-13 10:00:00Z],
      ...>   updated_at: ~U[2025-12-13 10:00:00Z]
      ...> }
      iex> provider = ProviderMapper.to_domain(schema)
      iex> provider.business_name
      "Kids Sports Academy"

  """
  @spec to_domain(ProviderSchema.t()) :: Provider.t()
  def to_domain(%ProviderSchema{} = schema) do
    %Provider{
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
  Converts a domain Provider entity to ProviderSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  This is used when creating or updating provider profiles in the database.

  ## Examples

      iex> provider = %Provider{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   business_name: "Kids Sports Academy",
      ...>   description: "Youth sports training",
      ...>   phone: "+1234567890",
      ...>   website: "https://example.com",
      ...>   address: "123 Sports Lane",
      ...>   logo_url: "https://example.com/logo.png",
      ...>   verified: true,
      ...>   verified_at: ~U[2025-01-15 10:00:00Z],
      ...>   categories: ["sports"]
      ...> }
      iex> attrs = ProviderMapper.to_schema(provider)
      iex> attrs.identity_id
      "550e8400-e29b-41d4-a716-446655440001"

  """
  @spec to_schema(Provider.t()) :: map()
  def to_schema(%Provider{} = provider) do
    %{
      identity_id: provider.identity_id,
      business_name: provider.business_name,
      description: provider.description,
      phone: provider.phone,
      website: provider.website,
      address: provider.address,
      logo_url: provider.logo_url,
      verified: provider.verified,
      verified_at: provider.verified_at,
      categories: provider.categories
    }
    |> maybe_add_id(provider.id)
  end

  @doc """
  Converts a list of ProviderSchema structs to a list of domain Provider entities.

  This is a convenience function for mapping collections returned from database queries.

  ## Examples

      iex> schemas = [
      ...>   %ProviderSchema{id: "id1", identity_id: "identity1", business_name: "Provider 1", ...},
      ...>   %ProviderSchema{id: "id2", identity_id: "identity2", business_name: "Provider 2", ...}
      ...> ]
      iex> providers = ProviderMapper.to_domain_list(schemas)
      iex> length(providers)
      2

  """
  @spec to_domain_list([ProviderSchema.t()]) :: [Provider.t()]
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  # Private helper to conditionally add id to attrs map
  # If id is nil, Ecto will auto-generate it
  defp maybe_add_id(attrs, nil), do: attrs
  defp maybe_add_id(attrs, id), do: Map.put(attrs, :id, id)
end
