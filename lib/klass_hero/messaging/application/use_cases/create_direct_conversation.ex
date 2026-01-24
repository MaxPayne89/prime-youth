defmodule KlassHero.Messaging.Application.UseCases.CreateDirectConversation do
  @moduledoc """
  Use case for creating a direct 1-on-1 conversation between a provider and a parent.

  This use case:
  1. Checks if the initiator can start conversations (entitlement check)
  2. Checks if a direct conversation already exists
  3. Creates a new conversation if none exists
  4. Adds both parties as participants
  5. Publishes a conversation_created event

  Free-tier parents cannot initiate conversations but can receive and reply to them.
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Entitlements
  alias KlassHero.Messaging.EventPublisher
  alias KlassHero.Repo

  require Logger

  @doc """
  Creates or retrieves a direct conversation between provider and user.

  ## Parameters
  - scope: The current user's scope (for entitlement checks)
  - provider_id: The provider's profile ID
  - target_user_id: The user ID to start conversation with

  ## Returns
  - `{:ok, conversation}` - New or existing conversation
  - `{:error, :not_entitled}` - User cannot initiate messaging
  - `{:error, reason}` - Other errors
  """
  @spec execute(Scope.t(), String.t(), String.t()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Conversation.t()}
          | {:error, :not_entitled | term()}
  def execute(%Scope{} = scope, provider_id, target_user_id) do
    with :ok <- check_entitlement(scope) do
      find_or_create_conversation(scope, provider_id, target_user_id)
    end
  end

  defp check_entitlement(scope) do
    if Entitlements.can_initiate_messaging?(scope) do
      :ok
    else
      Logger.debug("User not entitled to initiate messaging", user_id: scope.user.id)
      {:error, :not_entitled}
    end
  end

  defp find_or_create_conversation(scope, provider_id, target_user_id) do
    conversation_repo = conversation_repository()
    participant_repo = participant_repository()

    case conversation_repo.find_direct_conversation(provider_id, target_user_id) do
      {:ok, existing} ->
        Logger.debug("Found existing conversation", conversation_id: existing.id)
        {:ok, existing}

      {:error, :not_found} ->
        create_new_conversation(
          scope,
          provider_id,
          target_user_id,
          conversation_repo,
          participant_repo
        )
    end
  end

  defp create_new_conversation(
         scope,
         provider_id,
         target_user_id,
         conversation_repo,
         participant_repo
       ) do
    Repo.transaction(fn ->
      attrs = %{
        type: :direct,
        provider_id: provider_id
      }

      case conversation_repo.create(attrs) do
        {:ok, conversation} ->
          add_participants(conversation.id, scope.user.id, target_user_id, participant_repo)
          publish_event(conversation, [scope.user.id, target_user_id], provider_id)

          Logger.info("Created direct conversation",
            conversation_id: conversation.id,
            provider_id: provider_id,
            initiator_id: scope.user.id
          )

          conversation

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp add_participants(conversation_id, user_id_1, user_id_2, participant_repo) do
    {:ok, _} = participant_repo.add(%{conversation_id: conversation_id, user_id: user_id_1})
    {:ok, _} = participant_repo.add(%{conversation_id: conversation_id, user_id: user_id_2})
    :ok
  end

  defp publish_event(conversation, participant_ids, provider_id) do
    EventPublisher.publish_new_conversation(conversation, participant_ids, provider_id)
  end

  defp conversation_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_conversations]
  end

  defp participant_repository do
    Application.get_env(:klass_hero, :messaging)[:for_managing_participants]
  end
end
