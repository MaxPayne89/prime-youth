defmodule KlassHero.Messaging.EventPublisher do
  @moduledoc """
  Messaging-specific event publisher for real-time updates.

  This module publishes domain events to instance-specific PubSub topics
  for LiveView subscriptions using the shared event publishing infrastructure.

  ## Topics

  - `"conversation:{id}"` - Per-conversation updates (message sent, messages read)
  - `"user:{id}:messages"` - User notification updates (new conversations, notifications)

  ## Message Format

  All events are published as `{:domain_event, %DomainEvent{}}` tuples for
  consistency with the cross-context event system.

  ## Usage

  Use cases call the publish functions which handle both event creation and
  topic-specific publishing:

      EventPublisher.publish_message_sent(message)
      EventPublisher.publish_messages_read(conversation_id, user_id, read_at)
      EventPublisher.publish_new_conversation(conversation, participant_ids)
      EventPublisher.notify_users(user_ids, message, conversation)

  LiveViews subscribe using the topic helper functions:

      Phoenix.PubSub.subscribe(KlassHero.PubSub, EventPublisher.conversation_topic(id))
  """

  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Domain.Models.{Conversation, Message}
  alias KlassHero.Shared.EventPublishing

  require Logger

  # -----------------------------------------------------------------------------
  # Topic Helpers (for LiveView subscriptions)
  # -----------------------------------------------------------------------------

  @doc """
  Returns the PubSub topic for a conversation.

  Used by LiveViews to subscribe to real-time updates for a specific conversation.
  """
  @spec conversation_topic(String.t()) :: String.t()
  def conversation_topic(conversation_id), do: "conversation:#{conversation_id}"

  @doc """
  Returns the PubSub topic for a user's message notifications.

  Used by LiveViews to subscribe to new conversation and message notifications.
  """
  @spec user_messages_topic(String.t()) :: String.t()
  def user_messages_topic(user_id), do: "user:#{user_id}:messages"

  # -----------------------------------------------------------------------------
  # Event Publishing Functions
  # -----------------------------------------------------------------------------

  @doc """
  Publishes a message_sent event to the conversation topic.

  Creates a domain event and broadcasts it to all participants subscribed
  to the conversation.

  ## Parameters

  - `message` - The message that was sent

  ## Returns

  - `:ok` on successful publish
  """
  @spec publish_message_sent(Message.t()) :: :ok | {:error, term()}
  def publish_message_sent(%Message{} = message) do
    event =
      MessagingEvents.message_sent(
        message.conversation_id,
        message.id,
        message.sender_id,
        message.content,
        message.message_type,
        message.inserted_at
      )

    topic = conversation_topic(message.conversation_id)

    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        Logger.debug("Published message_sent event",
          topic: topic,
          message_id: message.id
        )

        :ok

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Publishes a messages_read event to the conversation topic.

  Notifies all participants that a user has read messages in the conversation.

  ## Parameters

  - `conversation_id` - The conversation ID
  - `user_id` - The user who marked as read
  - `read_at` - The timestamp when messages were marked as read

  ## Returns

  - `:ok` on successful publish
  """
  @spec publish_messages_read(String.t(), String.t(), DateTime.t()) :: :ok | {:error, term()}
  def publish_messages_read(conversation_id, user_id, read_at) do
    event = MessagingEvents.messages_read(conversation_id, user_id, read_at)
    topic = conversation_topic(conversation_id)

    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        Logger.debug("Published messages_read event",
          topic: topic,
          user_id: user_id
        )

        :ok

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Publishes a conversation_created event to user topics.

  Notifies all participants that a new conversation has been created.

  ## Parameters

  - `conversation` - The conversation that was created
  - `participant_ids` - List of user IDs who are participants
  - `provider_id` - The provider ID associated with the conversation

  ## Returns

  - `:ok` on successful publish
  """
  @spec publish_new_conversation(Conversation.t(), [String.t()], String.t()) ::
          :ok | {:error, term()}
  def publish_new_conversation(%Conversation{} = conversation, participant_ids, provider_id) do
    event =
      MessagingEvents.conversation_created(
        conversation.id,
        conversation.type,
        provider_id,
        participant_ids
      )

    results =
      Enum.map(participant_ids, fn user_id ->
        topic = user_messages_topic(user_id)
        EventPublishing.publisher_module().publish(event, topic)
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        Logger.debug("Published conversation_created event",
          conversation_id: conversation.id,
          user_count: length(participant_ids)
        )

        :ok

      error ->
        error
    end
  end

  @doc """
  Publishes a broadcast_sent event for a program broadcast.

  Notifies all enrolled parents that a broadcast message was sent.

  ## Parameters

  - `conversation` - The broadcast conversation
  - `program_id` - The program ID
  - `provider_id` - The provider who sent the broadcast
  - `message_id` - The broadcast message ID
  - `recipient_count` - Number of recipients

  ## Returns

  - `:ok` on successful publish
  """
  @spec publish_broadcast_sent(
          Conversation.t(),
          String.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) ::
          :ok | {:error, term()}
  def publish_broadcast_sent(
        %Conversation{} = conversation,
        program_id,
        provider_id,
        message_id,
        recipient_count
      ) do
    event =
      MessagingEvents.broadcast_sent(
        conversation.id,
        program_id,
        provider_id,
        message_id,
        recipient_count
      )

    topic = conversation_topic(conversation.id)

    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        Logger.debug("Published broadcast_sent event",
          topic: topic,
          conversation_id: conversation.id,
          recipient_count: recipient_count
        )

        :ok

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Notifies users of a new message in a conversation.

  Publishes the message_sent event to each user's notification topic for
  updating unread counts and showing notifications.

  ## Parameters

  - `user_ids` - List of user IDs to notify
  - `message` - The message to notify about
  - `conversation` - The conversation containing the message

  ## Returns

  - `:ok` on successful publish
  """
  @spec notify_users([String.t()], Message.t(), Conversation.t()) :: :ok | {:error, term()}
  def notify_users(user_ids, %Message{} = message, %Conversation{} = _conversation) do
    event =
      MessagingEvents.message_sent(
        message.conversation_id,
        message.id,
        message.sender_id,
        message.content,
        message.message_type,
        message.inserted_at
      )

    results =
      Enum.map(user_ids, fn user_id ->
        topic = user_messages_topic(user_id)
        EventPublishing.publisher_module().publish(event, topic)
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        Logger.debug("Notified users of new message",
          user_count: length(user_ids),
          message_id: message.id
        )

        :ok

      error ->
        error
    end
  end
end
