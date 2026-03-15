defmodule KlassHero.Messaging.Application.UseCases.Shared do
  @moduledoc """
  Shared utilities for Messaging use cases.
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Entitlements

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

  @doc """
  Checks whether the scope's user is entitled to initiate messaging.

  Returns `:ok` if entitled, or `{:error, :not_entitled}` otherwise.
  """
  @spec check_entitlement(Scope.t()) :: :ok | {:error, :not_entitled}
  def check_entitlement(%Scope{} = scope) do
    if Entitlements.can_initiate_messaging?(scope) do
      :ok
    else
      Logger.debug("Not entitled to initiate messaging", user_id: scope.user.id)
      {:error, :not_entitled}
    end
  end

  @doc """
  Conditionally checks entitlement based on opts.

  ## Options
  - `:skip_entitlement_check` - When `true`, bypasses the entitlement check.
  """
  # Trigger: skip_entitlement_check opt is set
  # Why: ReplyPrivatelyToBroadcast use case allows all tiers to reply
  #      privately — the provider initiated contact via broadcast.
  # Outcome: entitlement check is skipped, conversation creation proceeds
  @spec maybe_check_entitlement(Scope.t(), keyword()) :: :ok | {:error, :not_entitled}
  def maybe_check_entitlement(%Scope{} = scope, opts) do
    if Keyword.get(opts, :skip_entitlement_check, false) do
      :ok
    else
      check_entitlement(scope)
    end
  end
end
