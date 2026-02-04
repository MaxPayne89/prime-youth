defmodule KlassHero.Messaging.Application.UseCases.SendMessage do
  @moduledoc """
  Use case for sending a message in a conversation.

  This use case:
  1. Verifies the sender is a participant in the conversation
  2. Creates the message
  3. Updates the sender's last_read_at (they've seen what they sent)
  4. Publishes a message_sent event for real-time updates
  """

  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging

  @doc """
  Sends a message to a conversation.

  ## Parameters
  - conversation_id: The conversation to send to
  - sender_id: The user sending the message
  - content: The message content
  - opts: Optional parameters
    - message_type: :text (default) or :system

  ## Returns
  - `{:ok, message}` - Message sent successfully
  - `{:error, :not_participant}` - Sender is not in the conversation
  - `{:error, reason}` - Other errors
  """
  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Message.t()}
          | {:error, :not_participant | term()}
  def execute(conversation_id, sender_id, content, opts \\ []) do
    message_type = Keyword.get(opts, :message_type, :text)
    repos = Repositories.all()

    with :ok <- verify_participant(conversation_id, sender_id, repos.participants),
         {:ok, message} <-
           create_message(conversation_id, sender_id, content, message_type, repos.messages) do
      update_sender_read_status(conversation_id, sender_id, repos.participants)
      publish_event(message)

      Logger.info("Message sent",
        message_id: message.id,
        conversation_id: conversation_id,
        sender_id: sender_id
      )

      {:ok, message}
    end
  end

  defp verify_participant(conversation_id, user_id, participant_repo) do
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

  defp create_message(conversation_id, sender_id, content, message_type, message_repo) do
    attrs = %{
      conversation_id: conversation_id,
      sender_id: sender_id,
      content: String.trim(content),
      message_type: message_type
    }

    message_repo.create(attrs)
  end

  defp update_sender_read_status(conversation_id, sender_id, participant_repo) do
    now = DateTime.utc_now()

    case participant_repo.mark_as_read(conversation_id, sender_id, now) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to update sender read status",
          conversation_id: conversation_id,
          sender_id: sender_id,
          reason: inspect(reason)
        )

        :ok
    end
  end

  defp publish_event(message) do
    event =
      MessagingEvents.message_sent(
        message.conversation_id,
        message.id,
        message.sender_id,
        message.content,
        message.message_type,
        message.inserted_at
      )

    DomainEventBus.dispatch(@context, event)
    :ok
  end
end
