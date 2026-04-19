defmodule KlassHero.Messaging.Domain.Ports.ForManagingConversations do
  @moduledoc """
  Write-only port for managing conversations in the Messaging bounded context.

  This behaviour defines the contract for conversation mutation operations.
  Read operations are defined in `ForQueryingConversations`.
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

  Parameters:
  - `cutoff_date` - Programs ending before this datetime are considered ended
  - `retention_days` - Number of days to retain archived conversations

  Returns:
  - `{:ok, %{count: n, conversation_ids: [ids]}}` - Success with count and IDs
  - `{:error, reason}` - Failure
  """
  @callback archive_ended_program_conversations(
              cutoff_date :: DateTime.t(),
              retention_days :: pos_integer()
            ) ::
              {:ok, %{count: non_neg_integer(), conversation_ids: [String.t()]}}
end
