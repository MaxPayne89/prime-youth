defmodule KlassHero.Messaging.Application.UseCases.SendMessage do
  @moduledoc """
  Use case for sending a message in a conversation.

  This use case:
  1. Verifies the sender is a participant in the conversation
  2. Creates the message
  3. Updates the sender's last_read_at (they've seen what they sent)
  4. Publishes a message_sent event for real-time updates
  """

  alias KlassHero.Messaging.Application.UseCases.Shared
  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging
  @conversation_repo Application.compile_env!(:klass_hero, [
                       :messaging,
                       :for_managing_conversations
                     ])
  @message_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_messages])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])
  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])
  @staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

  @doc """
  Sends a message to a conversation.

  ## Parameters
  - conversation_id: The conversation to send to
  - sender_id: The user sending the message
  - content: The message content
  - opts: Optional parameters
    - message_type: :text (default) or :system
    - conversation: pre-fetched %Conversation{} domain struct for the same
      conversation_id (skips DB fetch in broadcast permission check; ignored
      if ID doesn't match)

  ## Returns
  - `{:ok, message}` - Message sent successfully
  - `{:error, :not_participant}` - Sender is not in the conversation
  - `{:error, reason}` - Other errors
  """
  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Message.t()}
          | {:error, :not_participant | :broadcast_reply_not_allowed | term()}
  def execute(conversation_id, sender_id, content, opts \\ []) do
    message_type = Keyword.get(opts, :message_type, :text)
    conversation = Keyword.get(opts, :conversation)

    with :ok <- Shared.verify_participant(conversation_id, sender_id, @participant_repo),
         :ok <- verify_broadcast_send_permission(conversation_id, sender_id, conversation),
         {:ok, message} <- create_message(conversation_id, sender_id, content, message_type) do
      update_sender_read_status(conversation_id, sender_id)
      publish_event(message)

      Logger.info("Message sent",
        message_id: message.id,
        conversation_id: conversation_id,
        sender_id: sender_id
      )

      {:ok, message}
    end
  end

  # Trigger: sender is trying to post in a broadcast conversation
  # Why: broadcast conversations are one-way — only the provider owner and assigned staff
  #      can send. Parents replying would expose their messages to all other parents
  #      (privacy breach).
  # Outcome: non-provider, non-staff senders are rejected; direct conversations pass through.
  defp verify_broadcast_send_permission(conversation_id, sender_id, conversation) do
    # Trigger: caller may pass a pre-fetched conversation to skip DB round-trip
    # Why: must validate conversation.id matches conversation_id to prevent
    #      a mismatched struct from bypassing broadcast guards (privacy breach)
    # Outcome: uses passed conversation only if ID matches; otherwise fetches from DB
    result =
      if conversation && conversation.id == conversation_id,
        do: {:ok, conversation},
        else: @conversation_repo.get_by_id(conversation_id)

    case result do
      {:ok, %{type: :program_broadcast, provider_id: provider_id, program_id: program_id}} ->
        cond do
          provider_owner?(provider_id, sender_id) -> :ok
          staff_assigned?(program_id, sender_id) -> :ok
          true -> {:error, :broadcast_reply_not_allowed}
        end

      {:ok, _direct_conversation} ->
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp provider_owner?(provider_id, sender_id) do
    case @user_resolver.get_user_id_for_provider(provider_id) do
      {:ok, ^sender_id} -> true
      _ -> false
    end
  end

  defp staff_assigned?(nil, _sender_id), do: false

  defp staff_assigned?(program_id, sender_id) do
    staff_user_ids = @staff_resolver.get_active_staff_user_ids(program_id)
    sender_id in staff_user_ids
  end

  defp create_message(conversation_id, sender_id, content, message_type) do
    attrs = %{
      conversation_id: conversation_id,
      sender_id: sender_id,
      content: String.trim(content),
      message_type: message_type
    }

    @message_repo.create(attrs)
  end

  defp update_sender_read_status(conversation_id, sender_id) do
    now = DateTime.utc_now()

    case @participant_repo.mark_as_read(conversation_id, sender_id, now) do
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
