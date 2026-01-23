defmodule KlassHero.Messaging.Domain.Events.MessagingEvents do
  @moduledoc """
  Factory module for creating messaging domain events.

  Events are published to PubSub for real-time updates and can be
  consumed by other bounded contexts for cross-context integration.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :conversation

  @doc """
  Creates a conversation_created event.

  Published when a new conversation is created (direct or broadcast).
  """
  @spec conversation_created(
          conversation_id :: String.t(),
          type :: :direct | :program_broadcast,
          provider_id :: String.t(),
          participant_ids :: [String.t()]
        ) :: DomainEvent.t()
  def conversation_created(conversation_id, type, provider_id, participant_ids) do
    DomainEvent.new(
      :conversation_created,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        type: type,
        provider_id: provider_id,
        participant_ids: participant_ids
      }
    )
  end

  @doc """
  Creates a message_sent event.

  Published when a message is sent to a conversation.
  """
  @spec message_sent(
          conversation_id :: String.t(),
          message_id :: String.t(),
          sender_id :: String.t(),
          content :: String.t(),
          message_type :: :text | :system
        ) :: DomainEvent.t()
  def message_sent(conversation_id, message_id, sender_id, content, message_type) do
    DomainEvent.new(
      :message_sent,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        message_id: message_id,
        sender_id: sender_id,
        content: content,
        message_type: message_type
      }
    )
  end

  @doc """
  Creates a messages_read event.

  Published when a user marks messages as read.
  """
  @spec messages_read(
          conversation_id :: String.t(),
          user_id :: String.t(),
          read_at :: DateTime.t()
        ) :: DomainEvent.t()
  def messages_read(conversation_id, user_id, read_at) do
    DomainEvent.new(
      :messages_read,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        user_id: user_id,
        read_at: read_at
      }
    )
  end

  @doc """
  Creates a broadcast_sent event.

  Published when a program broadcast is sent.
  """
  @spec broadcast_sent(
          conversation_id :: String.t(),
          program_id :: String.t(),
          provider_id :: String.t(),
          message_id :: String.t(),
          recipient_count :: non_neg_integer()
        ) :: DomainEvent.t()
  def broadcast_sent(conversation_id, program_id, provider_id, message_id, recipient_count) do
    DomainEvent.new(
      :broadcast_sent,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        program_id: program_id,
        provider_id: provider_id,
        message_id: message_id,
        recipient_count: recipient_count
      }
    )
  end

  @doc """
  Creates a conversation_archived event.

  Published when a conversation is archived.
  """
  @spec conversation_archived(
          conversation_id :: String.t(),
          reason :: :program_ended | :manual
        ) :: DomainEvent.t()
  def conversation_archived(conversation_id, reason) do
    DomainEvent.new(
      :conversation_archived,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        reason: reason
      }
    )
  end
end
