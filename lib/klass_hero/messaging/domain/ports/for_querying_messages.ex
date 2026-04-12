defmodule KlassHero.Messaging.Domain.Ports.ForQueryingMessages do
  @moduledoc """
  Read-only port for querying messages in the Messaging bounded context.

  Separated from `ForManagingMessages` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Messaging.Domain.Models.Message

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
              {:ok, [Message.t()], sender_names :: %{binary() => String.t()}, has_more :: boolean()}

  @doc """
  Gets the latest message for a conversation.

  Returns:
  - `{:ok, Message.t()}` - Latest message found
  - `{:error, :not_found}` - No messages in conversation
  """
  @callback get_latest(conversation_id :: binary()) ::
              {:ok, Message.t()} | {:error, :not_found}

  @doc """
  Counts unread messages for a user in a conversation.

  Messages are considered unread if they were inserted after last_read_at.
  """
  @callback count_unread(conversation_id :: binary(), last_read_at :: DateTime.t() | nil) ::
              non_neg_integer()
end
