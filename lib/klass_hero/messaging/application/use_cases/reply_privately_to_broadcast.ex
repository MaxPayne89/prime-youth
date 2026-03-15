defmodule KlassHero.Messaging.Application.UseCases.ReplyPrivatelyToBroadcast do
  @moduledoc """
  Use case for privately replying to a broadcast message.

  When a parent wants to respond to a broadcast, this use case:
  1. Fetches the broadcast conversation to get the provider
  2. Creates (or finds) a direct conversation with that provider
  3. Inserts a system message for context (idempotent)
  4. Returns the direct conversation ID for navigation
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging
  alias KlassHero.Messaging.Repositories

  require Logger

  @doc """
  Orchestrates a private reply to a broadcast.

  ## Parameters
  - scope: The parent's scope
  - broadcast_conversation_id: The broadcast conversation being replied to

  ## Returns
  - `{:ok, direct_conversation_id}` - Direct conversation ready for messaging
  - `{:error, :not_found}` - Broadcast conversation not found
  - `{:error, reason}` - Other errors
  """
  @spec execute(Scope.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute(%Scope{} = scope, broadcast_conversation_id) do
    repos = Repositories.all()

    with {:ok, broadcast} <- repos.conversations.get_by_id(broadcast_conversation_id),
         {:ok, provider_user_id} <- repos.users.get_user_id_for_provider(broadcast.provider_id),
         {:ok, direct_conversation} <-
           Messaging.create_direct_conversation(
             scope,
             broadcast.provider_id,
             provider_user_id,
             skip_entitlement_check: true
           ),
         :ok <-
           maybe_insert_system_note(
             direct_conversation,
             scope.user.id,
             broadcast,
             repos
           ) do
      Logger.info("Private reply to broadcast initiated",
        broadcast_id: broadcast_conversation_id,
        direct_conversation_id: direct_conversation.id,
        user_id: scope.user.id
      )

      {:ok, direct_conversation.id}
    end
  end

  # Trigger: parent initiates a private reply to a broadcast
  # Why: inserts a system note in the direct conversation so the provider
  #      knows which broadcast prompted the message. Dedup prevents duplicate
  #      notes if the parent taps "Reply privately" multiple times.
  # Outcome: exactly one system note per broadcast reference in the conversation
  defp maybe_insert_system_note(direct_conversation, sender_id, broadcast, repos) do
    token = "[broadcast:#{broadcast.id}]"

    if system_note_exists?(direct_conversation.id, token, repos.messages) do
      :ok
    else
      subject = broadcast.subject || "broadcast"
      content = "#{token} Re: #{subject}"

      with {:ok, _message} <-
             Messaging.send_message(direct_conversation.id, sender_id, content,
               message_type: :system
             ) do
        :ok
      end
    end
  end

  defp system_note_exists?(conversation_id, token, message_repo) do
    {:ok, messages, _} =
      message_repo.list_for_conversation(conversation_id, limit: 100)

    Enum.any?(messages, fn msg ->
      msg.message_type == :system and String.contains?(msg.content, token)
    end)
  end
end
