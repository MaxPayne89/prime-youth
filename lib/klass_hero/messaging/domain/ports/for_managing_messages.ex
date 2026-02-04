defmodule KlassHero.Messaging.Domain.Ports.ForManagingMessages do
  @moduledoc """
  Repository port for managing messages in the Messaging bounded context.

  This behaviour defines the contract for message persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Messaging.Domain.Models.Message

  @doc """
  Creates a new message.

  Returns:
  - `{:ok, Message.t()}` - Message created
  - `{:error, changeset}` - Validation failure
  """
  @callback create(attrs :: map()) ::
              {:ok, Message.t()} | {:error, term()}

  @doc """
  Retrieves a message by ID.

  Returns:
  - `{:ok, Message.t()}` - Message found
  - `{:error, :not_found}` - No message exists with the given ID
  """
  @callback get_by_id(id :: binary()) ::
              {:ok, Message.t()} | {:error, :not_found}

  @doc """
  Lists messages for a conversation with pagination.

  Returns messages ordered by inserted_at descending (newest first).

  Options:
  - limit: integer - max results (default 50)
  - before: DateTime - get messages before this timestamp
  - after: DateTime - get messages after this timestamp
  """
  @callback list_for_conversation(conversation_id :: binary(), opts :: keyword()) ::
              {:ok, [Message.t()], has_more :: boolean()}

  @doc """
  Lists messages with sender names extracted from preloaded data.

  Returns messages ordered by inserted_at descending (newest first),
  along with a map of sender_id => display_name built from preloaded sender data.

  Options:
  - limit: integer - max results (default 50)
  - before: DateTime - get messages before this timestamp
  - after: DateTime - get messages after this timestamp
  """
  @callback list_with_senders(conversation_id :: binary(), opts :: keyword()) ::
              {:ok, [Message.t()], sender_names :: %{binary() => String.t()},
               has_more :: boolean()}

  @doc """
  Gets the latest message for a conversation.

  Returns:
  - `{:ok, Message.t()}` - Latest message found
  - `{:error, :not_found}` - No messages in conversation
  """
  @callback get_latest(conversation_id :: binary()) ::
              {:ok, Message.t()} | {:error, :not_found}

  @doc """
  Soft deletes a message.

  Sets deleted_at timestamp.
  """
  @callback soft_delete(message :: Message.t()) ::
              {:ok, Message.t()} | {:error, term()}

  @doc """
  Counts unread messages for a user in a conversation.

  Messages are considered unread if they were inserted after last_read_at.
  """
  @callback count_unread(conversation_id :: binary(), last_read_at :: DateTime.t() | nil) ::
              non_neg_integer()

  @doc """
  Anonymizes all messages sent by a user.

  Replaces message content with `"[deleted]"` for all messages where
  the sender matches the given user ID. Used for GDPR data anonymization.

  Returns:
  - `{:ok, count}` - Number of messages anonymized
  - `{:error, :database_connection_error}` - Database connection failure
  - `{:error, :database_query_error}` - Database query failure
  """
  @callback anonymize_for_sender(sender_id :: binary()) ::
              {:ok, non_neg_integer()}
              | {:error, :database_connection_error | :database_query_error}

  @doc """
  Deletes all messages for conversations that have expired their retention period.

  Performs a bulk delete of messages where the associated conversation's
  retention_until is before the given timestamp.

  Returns:
  - `{:ok, count, conversation_ids}` - Count of deleted messages and affected conversation IDs
  """
  @callback delete_for_expired_conversations(before :: DateTime.t()) ::
              {:ok, non_neg_integer(), [String.t()]}
end
