defmodule KlassHero.Messaging.Domain.Ports.ForManagingConversations do
  @moduledoc """
  Repository port for managing conversations in the Messaging bounded context.

  This behaviour defines the contract for conversation persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Messaging.Domain.Models.Conversation

  @doc """
  Creates a new conversation.

  Returns:
  - `{:ok, Conversation.t()}` - Conversation created
  - `{:error, :duplicate_broadcast}` - Active broadcast already exists for program
  - `{:error, changeset}` - Validation failure
  """
  @callback create(attrs :: map()) ::
              {:ok, Conversation.t()} | {:error, :duplicate_broadcast | term()}

  @doc """
  Retrieves a conversation by ID with optional preloads.

  Options:
  - preload: [:participants, :messages] - associations to preload

  Returns:
  - `{:ok, Conversation.t()}` - Conversation found
  - `{:error, :not_found}` - No conversation exists with the given ID
  """
  @callback get_by_id(id :: binary(), opts :: keyword()) ::
              {:ok, Conversation.t()} | {:error, :not_found}

  @doc """
  Finds an existing direct conversation between provider and user.

  Returns:
  - `{:ok, Conversation.t()}` - Existing conversation found
  - `{:error, :not_found}` - No conversation exists
  """
  @callback find_direct_conversation(provider_id :: binary(), user_id :: binary()) ::
              {:ok, Conversation.t()} | {:error, :not_found}

  @doc """
  Lists all conversations for a user.

  Returns conversations where the user is an active participant,
  ordered by most recent message first.

  Options:
  - limit: integer - max results (default 50)
  - cursor: binary - pagination cursor
  """
  @callback list_for_user(user_id :: binary(), opts :: keyword()) ::
              {:ok, [Conversation.t()], has_more :: boolean()}

  @doc """
  Lists all conversations for a provider.

  Returns all conversations owned by the provider,
  ordered by most recent message first.

  Options:
  - limit: integer - max results (default 50)
  - cursor: binary - pagination cursor
  - type: :direct | :program_broadcast - filter by type
  """
  @callback list_for_provider(provider_id :: binary(), opts :: keyword()) ::
              {:ok, [Conversation.t()], has_more :: boolean()}

  @doc """
  Archives a conversation.

  Sets archived_at and retention_until timestamps.
  """
  @callback archive(conversation :: Conversation.t()) ::
              {:ok, Conversation.t()} | {:error, term()}

  @doc """
  Deletes all conversations that have passed their retention period.

  Returns count of deleted conversations.
  """
  @callback delete_expired(before :: DateTime.t()) :: {:ok, non_neg_integer()}

  @doc """
  Archives conversations for programs that ended before the cutoff date.

  Performs a bulk update, setting archived_at and retention_until for all
  matching program_broadcast conversations where the associated program
  has ended.

  Returns:
  - `{:ok, %{count: n, conversation_ids: [ids]}}` - Success with count and IDs
  - `{:error, reason}` - Failure
  """
  @callback archive_ended_program_conversations(cutoff_date :: Date.t()) ::
              {:ok, %{count: non_neg_integer(), conversation_ids: [String.t()]}}
end
