defmodule KlassHero.Messaging.Application.UseCases.MarkAsRead do
  @moduledoc """
  Use case for marking messages as read in a conversation.

  This use case:
  1. Verifies the user is a participant
  2. Updates last_read_at timestamp
  3. Publishes a messages_read event for real-time updates
  """

  alias KlassHero.Messaging.EventPublisher
  alias KlassHero.Messaging.Repositories

  require Logger

  @doc """
  Marks messages as read for a user in a conversation.

  ## Parameters
  - conversation_id: The conversation
  - user_id: The user marking as read
  - read_at: Optional timestamp (defaults to now)

  ## Returns
  - `{:ok, participant}` - Updated participant
  - `{:error, :not_participant}` - User is not in the conversation
  """
  @spec execute(String.t(), String.t(), DateTime.t() | nil) ::
          {:ok, KlassHero.Messaging.Domain.Models.Participant.t()}
          | {:error, :not_participant}
  def execute(conversation_id, user_id, read_at \\ nil) do
    participant_repo = Repositories.participants()
    read_at = read_at || DateTime.utc_now()

    case participant_repo.mark_as_read(conversation_id, user_id, read_at) do
      {:ok, participant} ->
        publish_event(conversation_id, user_id, read_at)

        Logger.debug("Marked as read",
          conversation_id: conversation_id,
          user_id: user_id,
          read_at: read_at
        )

        {:ok, participant}

      {:error, :not_found} ->
        {:error, :not_participant}
    end
  end

  defp publish_event(conversation_id, user_id, read_at) do
    case EventPublisher.publish_messages_read(conversation_id, user_id, read_at) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish messages_read event",
          conversation_id: conversation_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
