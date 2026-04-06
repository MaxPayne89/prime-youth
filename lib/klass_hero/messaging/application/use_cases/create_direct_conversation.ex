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
  alias KlassHero.Messaging.Application.UseCases.Shared
  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging
  @conversation_repo Application.compile_env!(:klass_hero, [
                       :messaging,
                       :for_managing_conversations
                     ])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])
  @user_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])

  @doc """
  Creates or retrieves a direct conversation between provider and user.

  ## Parameters
  - scope: The current user's scope (for entitlement checks)
  - provider_id: The provider's profile ID
  - target_user_id: The user ID to start conversation with
  - opts: Optional keyword list
    - `:skip_entitlement_check` - When `true`, bypasses the entitlement check.
      Used by ReplyPrivatelyToBroadcast so that any tier can reply when the
      provider initiated contact via a broadcast.

  ## Returns
  - `{:ok, conversation}` - New or existing conversation
  - `{:error, :not_entitled}` - User cannot initiate messaging
  - `{:error, reason}` - Other errors
  """
  @spec execute(Scope.t(), String.t(), String.t(), keyword()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Conversation.t()}
          | {:error, :not_entitled | term()}
  def execute(%Scope{} = scope, provider_id, target_user_id, opts \\ []) do
    with :ok <- Shared.maybe_check_entitlement(scope, opts) do
      find_or_create_conversation(scope, provider_id, target_user_id)
    end
  end

  @doc """
  Creates or retrieves a direct conversation with a provider, resolving the
  provider's user identity internally.

  Use this variant when the caller only has a `provider_id` (e.g. from a program
  record) and does not need to supply the provider's user ID explicitly.
  """
  @spec execute(Scope.t(), String.t()) ::
          {:ok, KlassHero.Messaging.Domain.Models.Conversation.t()}
          | {:error, :not_entitled | :not_found | term()}
  def execute(%Scope{} = scope, provider_id) when is_binary(provider_id) do
    with :ok <- Shared.maybe_check_entitlement(scope, []),
         {:ok, target_user_id} <- @user_resolver.get_user_id_for_provider(provider_id) do
      find_or_create_conversation(scope, provider_id, target_user_id)
    end
  end

  defp find_or_create_conversation(scope, provider_id, target_user_id) do
    case @conversation_repo.find_direct_conversation(provider_id, target_user_id) do
      {:ok, existing} ->
        Logger.debug("Found existing conversation", conversation_id: existing.id)
        {:ok, existing}

      {:error, :not_found} ->
        create_new_conversation(scope, provider_id, target_user_id)
    end
  end

  defp create_new_conversation(scope, provider_id, target_user_id) do
    Repo.transaction(fn ->
      attrs = %{
        type: :direct,
        provider_id: provider_id
      }

      with {:ok, conversation} <- @conversation_repo.create(attrs),
           :ok <- add_participants(conversation.id, scope.user.id, target_user_id) do
        publish_event(conversation, [scope.user.id, target_user_id], provider_id)

        Logger.info("Created direct conversation",
          conversation_id: conversation.id,
          provider_id: provider_id,
          initiator_id: scope.user.id
        )

        conversation
      else
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp add_participants(conversation_id, user_id_1, user_id_2) do
    with {:ok, _} <-
           @participant_repo.add(%{conversation_id: conversation_id, user_id: user_id_1}),
         {:ok, _} <-
           @participant_repo.add(%{conversation_id: conversation_id, user_id: user_id_2}) do
      :ok
    end
  end

  defp publish_event(conversation, participant_ids, provider_id) do
    event =
      MessagingEvents.conversation_created(
        conversation.id,
        conversation.type,
        provider_id,
        participant_ids
      )

    DomainEventBus.dispatch(@context, event)
    :ok
  end
end
