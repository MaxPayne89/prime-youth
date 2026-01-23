defmodule KlassHero.Messaging.EventPublisher do
  @moduledoc """
  Messaging-specific event publisher for real-time updates.

  Broadcasts messaging events to PubSub topics for LiveView subscriptions:
  - `"conversation:{id}"` - Per-conversation updates
  - `"user:{id}:messages"` - User notification updates
  """

  alias KlassHero.Messaging.Domain.Models.{Conversation, Message}

  require Logger

  @pubsub KlassHero.PubSub

  @doc """
  Broadcasts a new message to the conversation topic.

  All participants subscribed to the conversation will receive the update.
  """
  @spec broadcast_message(Message.t()) :: :ok
  def broadcast_message(%Message{} = message) do
    topic = conversation_topic(message.conversation_id)
    payload = {:new_message, message}

    Phoenix.PubSub.broadcast(@pubsub, topic, payload)

    Logger.debug("Broadcast message",
      topic: topic,
      message_id: message.id
    )
  end

  @doc """
  Broadcasts a new message notification to specific user topics.

  Used for updating unread counts and showing notifications.
  """
  @spec notify_users([String.t()], Message.t(), Conversation.t()) :: :ok
  def notify_users(user_ids, %Message{} = message, %Conversation{} = conversation) do
    payload = {:message_notification, %{message: message, conversation: conversation}}

    Enum.each(user_ids, fn user_id ->
      topic = user_messages_topic(user_id)
      Phoenix.PubSub.broadcast(@pubsub, topic, payload)
    end)

    Logger.debug("Notified users of new message",
      user_count: length(user_ids),
      message_id: message.id
    )
  end

  @doc """
  Broadcasts read receipt update to the conversation topic.
  """
  @spec broadcast_read_receipt(String.t(), String.t(), DateTime.t()) :: :ok
  def broadcast_read_receipt(conversation_id, user_id, read_at) do
    topic = conversation_topic(conversation_id)
    payload = {:messages_read, %{user_id: user_id, read_at: read_at}}

    Phoenix.PubSub.broadcast(@pubsub, topic, payload)

    Logger.debug("Broadcast read receipt",
      topic: topic,
      user_id: user_id
    )
  end

  @doc """
  Broadcasts new conversation notification to users.
  """
  @spec notify_new_conversation([String.t()], Conversation.t()) :: :ok
  def notify_new_conversation(user_ids, %Conversation{} = conversation) do
    payload = {:new_conversation, conversation}

    Enum.each(user_ids, fn user_id ->
      topic = user_messages_topic(user_id)
      Phoenix.PubSub.broadcast(@pubsub, topic, payload)
    end)

    Logger.debug("Notified users of new conversation",
      user_count: length(user_ids),
      conversation_id: conversation.id
    )
  end

  @doc """
  Returns the PubSub topic for a conversation.
  """
  @spec conversation_topic(String.t()) :: String.t()
  def conversation_topic(conversation_id), do: "conversation:#{conversation_id}"

  @doc """
  Returns the PubSub topic for a user's message notifications.
  """
  @spec user_messages_topic(String.t()) :: String.t()
  def user_messages_topic(user_id), do: "user:#{user_id}:messages"
end
