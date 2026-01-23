defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.MessageMapper do
  @moduledoc """
  Maps between MessageSchema (Ecto) and Message (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema
  alias KlassHero.Messaging.Domain.Models.Message

  @doc """
  Converts a MessageSchema to a domain Message.
  """
  @spec to_domain(MessageSchema.t()) :: Message.t()
  def to_domain(%MessageSchema{} = schema) do
    %Message{
      id: schema.id,
      conversation_id: schema.conversation_id,
      sender_id: schema.sender_id,
      content: schema.content,
      message_type: String.to_existing_atom(schema.message_type),
      deleted_at: schema.deleted_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a domain Message to attributes for schema creation.
  """
  @spec to_schema_attrs(Message.t()) :: map()
  def to_schema_attrs(%Message{} = message) do
    %{
      id: message.id,
      conversation_id: message.conversation_id,
      sender_id: message.sender_id,
      content: message.content,
      message_type: to_string(message.message_type),
      deleted_at: message.deleted_at
    }
  end

  @doc """
  Converts creation attributes to schema-compatible format.
  """
  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take([:conversation_id, :sender_id, :content, :message_type])
    |> Map.update(:message_type, "text", fn
      type when is_atom(type) -> to_string(type)
      nil -> "text"
      type -> type
    end)
  end
end
