defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.ParticipantMapper do
  @moduledoc """
  Maps between ParticipantSchema (Ecto) and Participant (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema
  alias KlassHero.Messaging.Domain.Models.Participant

  @doc """
  Converts a ParticipantSchema to a domain Participant.
  """
  @spec to_domain(ParticipantSchema.t()) :: Participant.t()
  def to_domain(%ParticipantSchema{} = schema) do
    %Participant{
      id: schema.id,
      conversation_id: schema.conversation_id,
      user_id: schema.user_id,
      last_read_at: schema.last_read_at,
      joined_at: schema.joined_at,
      left_at: schema.left_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain Participant to attributes for schema creation.
  """
  @spec to_schema_attrs(Participant.t()) :: map()
  def to_schema_attrs(%Participant{} = participant) do
    %{
      id: participant.id,
      conversation_id: participant.conversation_id,
      user_id: participant.user_id,
      last_read_at: participant.last_read_at,
      joined_at: participant.joined_at,
      left_at: participant.left_at
    }
  end

  @doc """
  Converts creation attributes to schema-compatible format.
  """
  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take([:conversation_id, :user_id, :joined_at, :last_read_at])
    |> Map.put_new(:joined_at, DateTime.utc_now())
  end
end
