defmodule KlassHero.Messaging.Application.Queries.GetTotalUnreadCount do
  @moduledoc """
  Use case for getting total unread message count across all conversations.

  Reads from the denormalized conversation_summaries read model (CQRS read side).
  Provides a simple count of unread messages for a user, useful for displaying
  notification badges in the navigation.
  """

  @conversation_summaries_reader Application.compile_env!(:klass_hero, [
                                   :messaging,
                                   :for_querying_conversation_summaries
                                 ])

  @doc """
  Gets total unread count for a user.

  Sums unread_count across all non-archived conversation summaries for the user.

  ## Parameters
  - user_id: The user to get unread count for

  ## Returns
  - Non-negative integer count
  """
  @spec execute(String.t()) :: non_neg_integer()
  def execute(user_id) do
    @conversation_summaries_reader.get_total_unread_count(user_id)
  end
end
