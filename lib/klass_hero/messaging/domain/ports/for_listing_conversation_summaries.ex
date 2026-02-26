defmodule KlassHero.Messaging.Domain.Ports.ForListingConversationSummaries do
  @moduledoc """
  Read port for querying the conversation_summaries denormalized read model.

  Implemented by the ConversationSummariesRepository adapter.
  """

  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary

  @callback list_for_user(user_id :: String.t(), opts :: keyword()) ::
              {:ok, [ConversationSummary.t()], has_more :: boolean()}

  @callback get_total_unread_count(user_id :: String.t()) :: non_neg_integer()
end
