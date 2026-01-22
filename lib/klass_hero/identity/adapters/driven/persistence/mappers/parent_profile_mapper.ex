defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ParentProfileMapper do
  @moduledoc """
  Maps between domain ParentProfile entities and ParentProfileSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ParentProfileSchema → ParentProfile (for reading from database)
  - to_schema/1: ParentProfile → ParentProfileSchema attributes (for creating/updating in database)
  - to_domain_list/1: [ParentProfileSchema] → [ParentProfile] (convenience for collections)

  The mapper is bidirectional to support both reading and writing parent profiles.

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert (conditionally included via maybe_add_id/2)
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. The repository handles id explicitly when needed
  (e.g., for updates or when domain entity already has an id).
  """

  import KlassHero.Identity.Adapters.Driven.Persistence.Mappers.MapperHelpers,
    only: [string_to_tier: 2, tier_to_string: 2, maybe_add_id: 2]

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Identity.Domain.Models.ParentProfile

  @doc """
  Converts an Ecto ParentProfileSchema to a domain ParentProfile entity.

  Returns the domain ParentProfile struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.
  Subscription tier is converted from string to atom.
  """
  def to_domain(%ParentProfileSchema{} = schema) do
    %ParentProfile{
      id: to_string(schema.id),
      identity_id: to_string(schema.identity_id),
      display_name: schema.display_name,
      phone: schema.phone,
      location: schema.location,
      notification_preferences: schema.notification_preferences,
      subscription_tier: string_to_tier(schema.subscription_tier, :explorer),
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain ParentProfile entity to ParentProfileSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  This is used when creating or updating parent profiles in the database.
  Subscription tier is converted from atom to string.
  """
  def to_schema(%ParentProfile{} = parent_profile) do
    %{
      identity_id: parent_profile.identity_id,
      display_name: parent_profile.display_name,
      phone: parent_profile.phone,
      location: parent_profile.location,
      notification_preferences: parent_profile.notification_preferences,
      subscription_tier: tier_to_string(parent_profile.subscription_tier, "explorer")
    }
    |> maybe_add_id(parent_profile.id)
  end

  @doc """
  Converts a list of ParentProfileSchema structs to a list of domain ParentProfile entities.

  This is a convenience function for mapping collections returned from database queries.
  """
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end
end
