defmodule KlassHero.Messaging.Domain.Ports.ForManagingMessages do
  @moduledoc """
  Write-only port for managing messages in the Messaging bounded context.

  This behaviour defines the contract for message mutation operations.
  Read operations are defined in `ForQueryingMessages`.
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
  Soft deletes a message.

  Sets deleted_at timestamp.
  """
  @callback soft_delete(message :: Message.t()) ::
              {:ok, Message.t()} | {:error, term()}

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
