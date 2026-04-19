defmodule KlassHero.Messaging.Domain.Ports.ForManagingConversationSummaries do
  @moduledoc """
  Write-only port for managing the conversation_summaries denormalized read model.

  This port defines the contract for targeted writes against the CQRS read table.
  The projection GenServer handles bulk writes; this port handles synchronous
  write-throughs.

  Read operations are defined in `ForQueryingConversationSummaries`.
  Implemented by the ConversationSummariesRepository adapter.
  """

  @doc """
  Writes a system note token directly to the conversation_summaries JSONB.

  This is a synchronous write-through used by use cases that need immediate
  visibility of the token. The projection also writes it asynchronously via
  the message_sent event — both writes are idempotent via JSONB merge.
  """
  @callback write_system_note_token(conversation_id :: String.t(), token :: String.t()) :: :ok
end
