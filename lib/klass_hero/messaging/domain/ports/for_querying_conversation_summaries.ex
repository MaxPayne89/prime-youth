defmodule KlassHero.Messaging.Domain.Ports.ForQueryingConversationSummaries do
  @moduledoc """
  Read-only port for querying conversation summaries in the Messaging bounded context.

  Separated from `ForManagingConversationSummaries` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
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
end
