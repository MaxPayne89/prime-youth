defmodule PrimeYouth.Parenting.Adapters.Driven.Events.IdentityEventHandler do
  @moduledoc """
  Event handler for Identity (Accounts) events that affect the Parenting context.

  This handler listens to user-related events from the Accounts context and
  automatically creates Parent profiles when users register with the "parent" role.

  ## Subscribed Events

  - `:user_registered` - Auto-creates Parent profile if "parent" in intended_roles

  ## Error Handling

  Profile creation errors are handled gracefully with retry logic:
  - Duplicate identity → :ok (profile already exists)
  - Transient errors → Retry once, then log error
  - All errors are logged but don't block event processing
  """

  @behaviour PrimeYouth.Shared.Domain.Ports.ForHandlingEvents

  alias PrimeYouth.Parenting
  alias PrimeYouth.Shared.Adapters.Driven.Events.RetryHelpers

  require Logger

  @impl true
  def subscribed_events, do: [:user_registered]

  @impl true
  def handle_event(%{event_type: :user_registered, aggregate_id: user_id, payload: payload}) do
    intended_roles = Map.get(payload, :intended_roles, [])

    if "parent" in intended_roles do
      create_parent_profile_with_retry(user_id)
    else
      :ignore
    end
  end

  def handle_event(_event), do: :ignore

  # Private functions

  defp create_parent_profile_with_retry(user_id) do
    operation = fn ->
      Parenting.create_parent_profile(%{identity_id: user_id})
    end

    context = %{
      operation_name: "create parent profile",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    case RetryHelpers.retry_with_backoff(operation, context) do
      :ok -> :ok
      {:ok, _parent} -> :ok
      {:error, _reason} = error -> error
    end
  end
end
