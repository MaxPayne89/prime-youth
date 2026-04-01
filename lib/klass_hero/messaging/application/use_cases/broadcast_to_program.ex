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
  alias KlassHero.Messaging.Application.UseCases.Shared
  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Domain.Models.Conversation
  alias KlassHero.Messaging.Domain.Models.Message
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging
  @conversation_repo Application.compile_env!(:klass_hero, [
                       :messaging,
                       :for_managing_conversations
                     ])
  @enrollment_resolver Application.compile_env!(:klass_hero, [
                         :messaging,
                         :for_querying_enrollments
                       ])
  @message_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_messages])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])

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
          {:ok, Conversation.t(), Message.t(), non_neg_integer()}
          | {:error, :not_entitled | :no_enrollments | term()}
  def execute(%Scope{} = scope, program_id, content, opts \\ []) do
    subject = Keyword.get(opts, :subject)

    with :ok <- Shared.check_entitlement(scope, provider_id: scope.provider.id),
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

  defp get_enrolled_parent_user_ids(program_id) do
    parent_ids = @enrollment_resolver.get_enrolled_parent_user_ids(program_id)
    {:ok, parent_ids}
  end

  defp verify_has_recipients([]), do: {:error, :no_enrollments}
  defp verify_has_recipients(_), do: :ok

  defp create_broadcast(scope, program_id, subject, content, parent_user_ids) do
    # Trigger: get-or-create runs OUTSIDE the transaction
    # Why: unique constraint violation inside Repo.transaction aborts the Postgres
    #      transaction — subsequent queries fail with 25P02 (in_failed_sql_transaction)
    # Outcome: conversation lookup/creation is isolated; only participant + message
    #          creation needs transactional consistency
    with {:ok, conversation} <-
           get_or_create_broadcast_conversation(scope, program_id, subject),
         {:ok, {conversation, message}} <-
           execute_broadcast_transaction(conversation, scope, content, parent_user_ids) do
      {:ok, conversation, message}
    end
  end

  defp execute_broadcast_transaction(conversation, scope, content, parent_user_ids) do
    Repo.transaction(fn ->
      with {:ok, _participants} <-
             @participant_repo.add_batch(conversation.id, parent_user_ids),
           {:ok, _} <-
             @participant_repo.add(%{
               conversation_id: conversation.id,
               user_id: scope.user.id
             }),
           :ok <-
             Shared.add_assigned_staff(conversation.id, conversation.program_id, scope.user.id),
           {:ok, message} <-
             @message_repo.create(%{
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
  end

  defp get_or_create_broadcast_conversation(scope, program_id, subject) do
    # Trigger: check for existing broadcast BEFORE attempting insert
    # Why: avoids unique constraint violation that would abort a parent transaction
    # Outcome: existing conversation reused; new one created only if none exists
    case @conversation_repo.find_active_broadcast_for_program(scope.provider.id, program_id) do
      {:ok, conversation} ->
        {:ok, conversation}

      {:error, :not_found} ->
        attrs = %{
          type: :program_broadcast,
          provider_id: scope.provider.id,
          program_id: program_id,
          subject: subject
        }

        case @conversation_repo.create(attrs) do
          {:ok, conversation} ->
            {:ok, conversation}

          # Trigger: race condition — another request created the conversation between
          #          our find and our create
          # Why: unique constraint fires; handle gracefully by re-querying
          # Outcome: return the conversation that won the race
          {:error, :duplicate_broadcast} ->
            @conversation_repo.find_active_broadcast_for_program(scope.provider.id, program_id)
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
