defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ConsentMapper do
  @moduledoc """
  Bidirectional mapping between Consent domain entities and ConsentSchema.

  Handles conversion between domain representation (string UUIDs) and
  database representation (binary UUIDs), ensuring clean separation
  between domain and infrastructure layers.
  """

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Identity.Domain.Models.Consent

  @doc """
  Converts a ConsentSchema (from database) to a Consent domain entity.
  """
  def to_domain(%ConsentSchema{} = schema) do
    %Consent{
      id: Ecto.UUID.cast!(schema.id),
      parent_id: Ecto.UUID.cast!(schema.parent_id),
      child_id: Ecto.UUID.cast!(schema.child_id),
      consent_type: schema.consent_type,
      granted_at: schema.granted_at,
      withdrawn_at: schema.withdrawn_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a list of ConsentSchema records to Consent domain entities.
  """
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end
end
