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
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging

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
    repos = Repositories.all()

    with :ok <- check_entitlement(scope),
         {:ok, parent_user_ids} <- get_enrolled_parent_user_ids(program_id, repos),
         :ok <- verify_has_recipients(parent_user_ids),
         {:ok, conversation, message} <-
           create_broadcast(scope, program_id, subject, content, parent_user_ids, repos) do
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

  defp get_enrolled_parent_user_ids(program_id, repos) do
    parent_ids = repos.enrollments.get_enrolled_parent_user_ids(program_id)
    {:ok, parent_ids}
  end

  defp verify_has_recipients([]), do: {:error, :no_enrollments}
  defp verify_has_recipients(_), do: :ok

  defp create_broadcast(scope, program_id, subject, content, parent_user_ids, repos) do
    Repo.transaction(fn ->
      with {:ok, conversation} <-
             get_or_create_broadcast_conversation(scope, program_id, subject, repos.conversations),
           {:ok, _participants} <- repos.participants.add_batch(conversation.id, parent_user_ids),
           {:ok, _} <-
             repos.participants.add(%{conversation_id: conversation.id, user_id: scope.user.id}),
           {:ok, message} <-
             repos.messages.create(%{
               conversation_id: conversation.id,
               sender_id: scope.user.id,
               content: String.trim(content),
               message_type: :text
             }) do
        {conversation, message}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
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
        {:ok, conversation}

      {:error, :duplicate_broadcast} ->
        find_existing_broadcast(scope.provider.id, program_id, conversation_repo)
    end
  end

  defp find_existing_broadcast(provider_id, program_id, conversation_repo) do
    with {:ok, existing, _has_more} <-
           conversation_repo.list_for_provider(provider_id, type: :program_broadcast) do
      existing
      |> Enum.find(fn c -> c.program_id == program_id end)
      |> case do
        nil -> {:error, :broadcast_not_found}
        conversation -> {:ok, conversation}
      end
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

    DomainEventBus.dispatch(@context, event)
    :ok
  end
end
