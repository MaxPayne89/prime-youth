defmodule KlassHero.Messaging.Application.UseCases.GetTotalUnreadCount do
  @moduledoc """
  Use case for getting total unread message count across all conversations.

  This use case provides a simple count of unread messages for a user,
  useful for displaying notification badges in the navigation.
  """

  alias KlassHero.Messaging.Repositories

  @doc """
  Gets total unread count for a user.

  Counts unread messages in all active conversations where the user is a participant.
  Excludes archived conversations and conversations the user has left.

  ## Parameters
  - user_id: The user to get unread count for

  ## Returns
  - Non-negative integer count
  """
  @spec execute(String.t()) :: non_neg_integer()
  def execute(user_id) do
    repos = Repositories.all()
    repos.conversations.get_total_unread_count(user_id)
  end
end
