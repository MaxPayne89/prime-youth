defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Mappers.ParentMapper do
  @moduledoc """
  Maps between domain Parent entities and ParentSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ParentSchema → Parent (for reading from database)
  - from_domain/1: Parent → ParentSchema attributes (for creating/updating in database)
  - to_domain_list/1: [ParentSchema] → [Parent] (convenience for collections)

  The mapper is bidirectional to support both reading and writing parent profiles.
  """

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema
  alias PrimeYouth.Parenting.Domain.Models.Parent

  @doc """
  Converts an Ecto ParentSchema to a domain Parent entity.

  Returns the domain Parent struct with all fields mapped from the schema.
  UUIDs are converted to strings to maintain domain independence from Ecto types.

  ## Examples

      iex> schema = %ParentSchema{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   display_name: "John Doe",
      ...>   phone: "+1234567890",
      ...>   location: "New York, NY",
      ...>   notification_preferences: %{email: true, sms: false},
      ...>   inserted_at: ~U[2025-12-13 10:00:00Z],
      ...>   updated_at: ~U[2025-12-13 10:00:00Z]
      ...> }
      iex> parent = ParentMapper.to_domain(schema)
      iex> parent.display_name
      "John Doe"

  """
  @spec to_domain(ParentSchema.t()) :: Parent.t()
  def to_domain(%ParentSchema{} = schema) do
    %Parent{
      id: to_string(schema.id),
      identity_id: to_string(schema.identity_id),
      display_name: schema.display_name,
      phone: schema.phone,
      location: schema.location,
      notification_preferences: schema.notification_preferences,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain Parent entity to ParentSchema attributes map.

  Returns a map suitable for Ecto changeset operations (insert/update).
  This is used when creating or updating parent profiles in the database.

  ## Examples

      iex> parent = %Parent{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   display_name: "John Doe",
      ...>   phone: "+1234567890",
      ...>   location: "New York, NY",
      ...>   notification_preferences: %{email: true}
      ...> }
      iex> attrs = ParentMapper.from_domain(parent)
      iex> attrs.identity_id
      "550e8400-e29b-41d4-a716-446655440001"

  """
  @spec from_domain(Parent.t()) :: map()
  def from_domain(%Parent{} = parent) do
    %{
      identity_id: parent.identity_id,
      display_name: parent.display_name,
      phone: parent.phone,
      location: parent.location,
      notification_preferences: parent.notification_preferences
    }
    |> maybe_add_id(parent.id)
  end

  @doc """
  Converts a list of ParentSchema structs to a list of domain Parent entities.

  This is a convenience function for mapping collections returned from database queries.

  ## Examples

      iex> schemas = [
      ...>   %ParentSchema{id: "id1", identity_id: "identity1", ...},
      ...>   %ParentSchema{id: "id2", identity_id: "identity2", ...}
      ...> ]
      iex> parents = ParentMapper.to_domain_list(schemas)
      iex> length(parents)
      2

  """
  @spec to_domain_list([ParentSchema.t()]) :: [Parent.t()]
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  # Private helper to conditionally add id to attrs map
  # If id is nil, Ecto will auto-generate it
  defp maybe_add_id(attrs, nil), do: attrs
  defp maybe_add_id(attrs, id), do: Map.put(attrs, :id, id)
end
