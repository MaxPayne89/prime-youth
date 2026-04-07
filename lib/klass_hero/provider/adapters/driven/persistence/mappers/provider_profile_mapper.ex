defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper do
  @moduledoc """
  Maps between domain ProviderProfile entities and ProviderProfileSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ProviderProfileSchema -> ProviderProfile (for reading from database)
  - to_schema/1: ProviderProfile -> ProviderProfileSchema attributes (for creating/updating in database)
  The mapper is bidirectional to support both reading and writing provider profiles.

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert (conditionally included via maybe_add_id/2)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. The repository handles id explicitly when needed
  (e.g., for updates or when domain entity already has an id).
  """

  import KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpers,
    only: [string_to_tier: 2, tier_to_string: 2, maybe_add_id: 2]

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Provider.Domain.Models.ProviderProfile

  require Logger

  @doc """
  Converts an Ecto ProviderProfileSchema to a domain ProviderProfile entity.

  Returns the domain ProviderProfile struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.
  Subscription tier is converted from string to atom.
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
      verified_by_id: schema.verified_by_id && to_string(schema.verified_by_id),
      categories: schema.categories,
      subscription_tier: string_to_tier(schema.subscription_tier, :starter),
      originated_from: string_to_origin(schema.originated_from),
      stripe_identity_session_id: schema.stripe_identity_session_id,
      stripe_identity_status: string_to_stripe_status(schema.stripe_identity_status),
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain ProviderProfile entity to ProviderProfileSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  This is used when creating or updating provider profiles in the database.
  Subscription tier is converted from atom to string.
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
      verified_by_id: provider_profile.verified_by_id,
      categories: provider_profile.categories,
      subscription_tier: tier_to_string(provider_profile.subscription_tier, "starter"),
      originated_from: origin_to_string(provider_profile.originated_from),
      stripe_identity_session_id: provider_profile.stripe_identity_session_id,
      stripe_identity_status: stripe_status_to_string(provider_profile.stripe_identity_status)
    }
    |> maybe_add_id(provider_profile.id)
  end

  defp string_to_origin("staff_invite"), do: :staff_invite
  defp string_to_origin("direct"), do: :direct
  defp string_to_origin(nil), do: :direct

  defp string_to_origin(other) do
    Logger.warning("[ProviderProfileMapper] Unknown originated_from value: #{inspect(other)}")
    :direct
  end

  defp origin_to_string(:staff_invite), do: "staff_invite"
  defp origin_to_string(_), do: "direct"

  defp string_to_stripe_status(nil), do: :not_started
  defp string_to_stripe_status("not_started"), do: :not_started
  defp string_to_stripe_status("pending"), do: :pending
  defp string_to_stripe_status("verified"), do: :verified
  defp string_to_stripe_status("requires_input"), do: :requires_input
  defp string_to_stripe_status("canceled"), do: :canceled
  defp string_to_stripe_status(_), do: :not_started

  defp stripe_status_to_string(:not_started), do: "not_started"
  defp stripe_status_to_string(:pending), do: "pending"
  defp stripe_status_to_string(:verified), do: "verified"
  defp stripe_status_to_string(:requires_input), do: "requires_input"
  defp stripe_status_to_string(:canceled), do: "canceled"
  defp stripe_status_to_string(nil), do: "not_started"
end
