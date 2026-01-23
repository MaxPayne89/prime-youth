defmodule KlassHero.Messaging.Application.UseCases.BroadcastToProgram do
  @moduledoc """
  Use case for sending a broadcast message to all enrolled parents of a program.

  This use case:
  1. Checks if the provider can send broadcasts (entitlement check)
  2. Creates or retrieves the program broadcast conversation
  3. Adds all enrolled parents as participants
  4. Sends the broadcast message
  5. Publishes events for real-time updates
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Entitlements
  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Repo

  require Logger

  @doc """
  Sends a broadcast message to all enrolled parents of a program.

  ## Parameters
  - scope: The provider's scope (for entitlement checks)
  - program_id: The program to broadcast to
  - content: The message content
  - opts: Optional parameters
    - subject: Subject line for the broadcast

  ## Returns
  - `{:ok, conversation, message, recipient_count}` - Broadcast sent
  - `{:error, :not_entitled}` - Provider cannot send broadcasts
  - `{:error, :no_enrollments}` - No enrolled parents to broadcast to
  - `{:error, reason}` - Other errors
  """
  @spec execute(Scope.t(), String.t(), String.t(), keyword()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Conversation.t(),
           KlassHero.Messaging.Domain.Models.Message.t(), non_neg_integer()}
          | {:error, :not_entitled | :no_enrollments | term()}
  def execute(%Scope{} = scope, program_id, content, opts \\ []) do
    subject = Keyword.get(opts, :subject)

    with :ok <- check_entitlement(scope),
         {:ok, parent_user_ids} <- get_enrolled_parent_user_ids(program_id),
         :ok <- verify_has_recipients(parent_user_ids),
         {:ok, conversation, message} <-
           create_broadcast(scope, program_id, subject, content, parent_user_ids) do
      recipient_count = length(parent_user_ids)
      publish_event(conversation, program_id, scope.provider.id, message.id, recipient_count)

      Logger.info("Broadcast sent to program",
        program_id: program_id,
        conversation_id: conversation.id,
        recipient_count: recipient_count
      )

      {:ok, conversation, message, recipient_count}
    end
  end

  defp check_entitlement(scope) do
    if Entitlements.can_initiate_messaging?(scope) do
      :ok
    else
      Logger.debug("Provider not entitled to broadcast", provider_id: scope.provider.id)
      {:error, :not_entitled}
    end
  end

  defp get_enrolled_parent_user_ids(program_id) do
    parent_ids = enrollment_resolver().get_enrolled_parent_user_ids(program_id)
    {:ok, parent_ids}
  end

  defp verify_has_recipients([]), do: {:error, :no_enrollments}
  defp verify_has_recipients(_), do: :ok

  defp create_broadcast(scope, program_id, subject, content, parent_user_ids) do
    conversation_repo = conversation_repository()
    participant_repo = participant_repository()
    message_repo = message_repository()

    Repo.transaction(fn ->
      conversation =
        get_or_create_broadcast_conversation(scope, program_id, subject, conversation_repo)

      {:ok, _participants} = participant_repo.add_batch(conversation.id, parent_user_ids)
      {:ok, _} = participant_repo.add(%{conversation_id: conversation.id, user_id: scope.user.id})

      {:ok, message} =
        message_repo.create(%{
          conversation_id: conversation.id,
          sender_id: scope.user.id,
          content: String.trim(content),
          message_type: :text
        })

      {conversation, message}
    end)
    |> case do
      {:ok, {conversation, message}} -> {:ok, conversation, message}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_or_create_broadcast_conversation(scope, program_id, subject, conversation_repo) do
    attrs = %{
      type: :program_broadcast,
      provider_id: scope.provider.id,
      program_id: program_id,
      subject: subject
    }

    case conversation_repo.create(attrs) do
      {:ok, conversation} ->
        conversation

      {:error, :duplicate_broadcast} ->
        {:ok, existing, _has_more} =
          conversation_repo.list_for_provider(scope.provider.id, type: :program_broadcast)

        Enum.find(existing, fn c -> c.program_id == program_id end)
    end
  end

  defp publish_event(conversation, program_id, provider_id, message_id, recipient_count) do
    event =
      MessagingEvents.broadcast_sent(
        conversation.id,
        program_id,
        provider_id,
        message_id,
        recipient_count
      )

    event_publisher().publish(event)
  end

  defp conversation_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_conversations]
  end

  defp participant_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_participants]
  end

  defp message_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_messages]
  end

  defp enrollment_resolver do
    Application.get_env(:klass_hero, :messaging)[:for_querying_enrollments]
  end

  defp event_publisher do
    Application.get_env(:klass_hero, :event_publisher)[:module]
  end
end
