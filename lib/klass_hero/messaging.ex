defmodule KlassHero.Messaging do
  @moduledoc """
  Public API facade for the Messaging bounded context.

  This module provides the primary interface for messaging functionality:
  - Direct 1-on-1 conversations between providers and parents
  - Program broadcast messages to all enrolled parents
  - Real-time message delivery via PubSub

  ## Conversation Types

  - `:direct` - Private conversation between one provider and one parent
  - `:program_broadcast` - Announcement from provider to all enrolled parents

  ## Entitlements

  Free-tier parents cannot initiate conversations but can receive and reply.
  Use `KlassHero.Entitlements.can_initiate_messaging?/1` to check permissions.

  ## Real-time Updates

  Subscribe to PubSub topics for real-time updates:
  - `"conversation:{id}"` - Per-conversation updates
  - `"user:{id}:messages"` - User notification updates
  """

  alias KlassHero.Accounts.Scope

  alias KlassHero.Messaging.Application.UseCases.{
    BroadcastToProgram,
    CreateDirectConversation,
    GetConversation,
    GetTotalUnreadCount,
    ListConversations,
    MarkAsRead,
    SendMessage
  }

  alias KlassHero.Messaging.Domain.Models.{Conversation, Message, Participant}

  @doc """
  Creates or retrieves a direct conversation between provider and user.

  If a direct conversation already exists, returns it.
  Otherwise creates a new one.

  ## Parameters
  - scope: The initiating user's scope (for entitlement checks)
  - provider_id: The provider's profile ID
  - target_user_id: The user ID to converse with

  ## Returns
  - `{:ok, conversation}` - The new or existing conversation
  - `{:error, :not_entitled}` - User cannot initiate messaging

  ## Examples

      iex> Messaging.create_direct_conversation(scope, provider_id, parent_user_id)
      {:ok, %Conversation{type: :direct, ...}}

  """
  @spec create_direct_conversation(Scope.t(), String.t(), String.t()) ::
          {:ok, Conversation.t()} | {:error, :not_entitled | term()}
  defdelegate create_direct_conversation(scope, provider_id, target_user_id),
    to: CreateDirectConversation,
    as: :execute

  @doc """
  Retrieves a conversation with its messages.

  ## Parameters
  - conversation_id: The conversation to retrieve
  - user_id: The requesting user (for access control)
  - opts: Optional parameters
    - limit: Number of messages (default 50)
    - before: Get messages before this timestamp
    - mark_as_read: Whether to mark messages as read (default false)

  ## Returns
  - `{:ok, result_map}` - Success, with keys:
    - `:conversation` - The conversation entity
    - `:messages` - List of messages
    - `:has_more` - Whether there are more messages
    - `:sender_names` - Map of sender_id => display name
  - `{:error, :not_found}` - Conversation doesn't exist
  - `{:error, :not_participant}` - User is not in the conversation

  ## Examples

      iex> Messaging.get_conversation(conversation_id, user_id)
      {:ok, %{conversation: %Conversation{}, messages: [...], has_more: false, sender_names: %{}}}

  """
  @spec get_conversation(String.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :not_found | :not_participant}
  defdelegate get_conversation(conversation_id, user_id, opts \\ []),
    to: GetConversation,
    as: :execute

  @doc """
  Lists conversations for a user with unread counts.

  Returns conversations ordered by most recent message.

  ## Parameters
  - user_id: The user to list conversations for
  - opts: Optional parameters
    - limit: Number of conversations (default 50)

  ## Returns
  - `{:ok, conversations, has_more}` - List of enriched conversations

  Each conversation includes:
  - `:conversation` - The conversation entity
  - `:unread_count` - Number of unread messages
  - `:latest_message` - The most recent message
  - `:last_read_at` - When user last read

  ## Examples

      iex> Messaging.list_conversations(user_id)
      {:ok, [%{conversation: %Conversation{}, unread_count: 2, ...}], false}

  """
  @spec list_conversations(String.t(), keyword()) :: {:ok, [map()], boolean()}
  defdelegate list_conversations(user_id, opts \\ []),
    to: ListConversations,
    as: :execute

  @doc """
  Sends a message to a conversation.

  The sender must be a participant in the conversation.

  ## Parameters
  - conversation_id: The conversation to send to
  - sender_id: The user sending the message
  - content: The message content
  - opts: Optional parameters
    - message_type: :text (default) or :system

  ## Returns
  - `{:ok, message}` - Message sent successfully
  - `{:error, :not_participant}` - Sender is not in the conversation

  ## Examples

      iex> Messaging.send_message(conversation_id, sender_id, "Hello!")
      {:ok, %Message{content: "Hello!", ...}}

  """
  @spec send_message(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, Message.t()} | {:error, :not_participant | term()}
  defdelegate send_message(conversation_id, sender_id, content, opts \\ []),
    to: SendMessage,
    as: :execute

  @doc """
  Marks messages as read in a conversation.

  Updates the participant's last_read_at timestamp.

  ## Parameters
  - conversation_id: The conversation
  - user_id: The user marking as read
  - read_at: Optional timestamp (defaults to now)

  ## Returns
  - `{:ok, participant}` - Updated participant
  - `{:error, :not_participant}` - User is not in the conversation

  ## Examples

      iex> Messaging.mark_as_read(conversation_id, user_id)
      {:ok, %Participant{last_read_at: ~U[...], ...}}

  """
  @spec mark_as_read(String.t(), String.t(), DateTime.t() | nil) ::
          {:ok, Participant.t()} | {:error, :not_participant}
  defdelegate mark_as_read(conversation_id, user_id, read_at \\ nil),
    to: MarkAsRead,
    as: :execute

  @doc """
  Sends a broadcast message to all enrolled parents of a program.

  Creates a program broadcast conversation if one doesn't exist,
  adds all enrolled parents as participants, and sends the message.

  ## Parameters
  - scope: The provider's scope (for entitlement checks)
  - program_id: The program to broadcast to
  - content: The message content
  - opts: Optional parameters
    - subject: Subject line for the broadcast

  ## Returns
  - `{:ok, conversation, message, recipient_count}` - Broadcast sent
  - `{:error, :not_entitled}` - Provider cannot send broadcasts
  - `{:error, :no_enrollments}` - No enrolled parents

  ## Examples

      iex> Messaging.broadcast_to_program(scope, program_id, "Important update!")
      {:ok, %Conversation{type: :program_broadcast}, %Message{}, 15}

  """
  @spec broadcast_to_program(Scope.t(), String.t(), String.t(), keyword()) ::
          {:ok, Conversation.t(), Message.t(), non_neg_integer()}
          | {:error, :not_entitled | :no_enrollments | term()}
  defdelegate broadcast_to_program(scope, program_id, content, opts \\ []),
    to: BroadcastToProgram,
    as: :execute

  @doc """
  Gets the total unread message count across all conversations for a user.

  This is useful for displaying an unread badge in the navigation.

  ## Parameters
  - user_id: The user to get unread count for

  ## Returns
  - Non-negative integer count of unread messages

  ## Examples

      iex> Messaging.get_total_unread_count(user_id)
      5

  """
  @spec get_total_unread_count(String.t()) :: non_neg_integer()
  defdelegate get_total_unread_count(user_id),
    to: GetTotalUnreadCount,
    as: :execute

  @doc """
  Subscribes to real-time updates for a conversation.

  ## Examples

      iex> Messaging.subscribe_to_conversation(conversation_id)
      :ok

  """
  @spec subscribe_to_conversation(String.t()) :: :ok | {:error, term()}
  def subscribe_to_conversation(conversation_id) do
    Phoenix.PubSub.subscribe(KlassHero.PubSub, "conversation:#{conversation_id}")
  end

  @doc """
  Subscribes to real-time updates for a user's messages.

  ## Examples

      iex> Messaging.subscribe_to_user_messages(user_id)
      :ok

  """
  @spec subscribe_to_user_messages(String.t()) :: :ok | {:error, term()}
  def subscribe_to_user_messages(user_id) do
    Phoenix.PubSub.subscribe(KlassHero.PubSub, "user:#{user_id}:messages")
  end
end
