defmodule KlassHero.Messaging.Domain.Ports.ForListingConversationSummaries do
  @moduledoc """
  Read port for querying the conversation_summaries denormalized read model.

  This port defines the contract for read-side queries against the CQRS
  read table. The projection GenServer handles writes; this port handles
  reads only.

  Implemented by the ConversationSummariesRepository adapter.
  """

  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary

  @doc """
  Lists conversation summaries for a specific user with pagination.

  Returns the user's conversation inbox ordered by most recent activity.
  Supports limit-based pagination via opts.

  ## Options

  - `:limit` - Maximum number of summaries to return (default: 25)

  ## Returns

  A 3-tuple `{:ok, summaries, has_more}`:
  - `summaries` - List of `ConversationSummary.t()` structs
  - `has_more` - Boolean indicating whether more results exist beyond the limit
  """
  @callback list_for_user(user_id :: String.t(), opts :: keyword()) ::
              {:ok, [ConversationSummary.t()], has_more :: boolean()}

  @doc """
  Returns the total count of unread messages across all conversations for a user.

  Used for badge/notification counts in the UI. Returns 0 if the user
  has no unread messages or no conversations.
  """
  @callback get_total_unread_count(user_id :: String.t()) :: non_neg_integer()

  @doc """
  Checks whether a system note with the given token exists for a conversation.

  Used for idempotent system note insertion — returns true if the token
  has already been projected into the conversation's system_notes JSONB.

  This is a boolean existence check that bypasses the ConversationSummary
  DTO entirely.
  """
  @callback has_system_note?(conversation_id :: String.t(), token :: String.t()) :: boolean()

  @doc """
  Writes a system note token directly to the conversation_summaries JSONB.

  This is a synchronous write-through used by use cases that need immediate
  visibility of the token. The projection also writes it asynchronously via
  the message_sent event — both writes are idempotent via JSONB merge.
  """
  @callback write_system_note_token(conversation_id :: String.t(), token :: String.t()) :: :ok
end
