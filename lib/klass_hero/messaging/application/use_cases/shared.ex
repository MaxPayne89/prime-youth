defmodule KlassHero.Messaging.Application.UseCases.Shared do
  @moduledoc """
  Shared utilities for Messaging use cases.
  """

  require Logger

  @doc """
  Verifies that a user is a participant in a conversation.

  Returns `:ok` if the user is a participant, or `{:error, :not_participant}` otherwise.
  """
  @spec verify_participant(String.t(), String.t(), module()) :: :ok | {:error, :not_participant}
  def verify_participant(conversation_id, user_id, participant_repo) do
    if participant_repo.is_participant?(conversation_id, user_id) do
      :ok
    else
      Logger.debug("User not participant in conversation",
        conversation_id: conversation_id,
        user_id: user_id
      )

      {:error, :not_participant}
    end
  end
end
