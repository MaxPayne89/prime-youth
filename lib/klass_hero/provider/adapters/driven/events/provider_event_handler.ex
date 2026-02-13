defmodule KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler do
  @moduledoc """
  Integration event handler for the Provider context.

  Listens to user-related events from the Accounts context and reacts accordingly:

  ## Subscribed Events

  - `:user_registered` - Creates provider profile if "provider" in intended_roles
  - `:user_anonymized` - No-op for Provider context (provider profiles have no PII
    beyond business_name which is retained for audit purposes)

  ## Error Handling

  Operations are handled gracefully with retry logic:
  - Duplicate identity → :ok (profile already exists)
  - Transient errors → Retry once, then log error
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

  alias KlassHero.Provider
  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  @impl true
  def subscribed_events, do: [:user_registered, :user_anonymized]

  @impl true
  def handle_event(%{event_type: :user_anonymized, entity_id: _user_id}) do
    # Trigger: user_anonymized event received
    # Why: provider profiles retain business_name for audit — no PII to anonymize
    # Outcome: no-op, return :ok
    :ok
  end

  @impl true
  def handle_event(%{event_type: :user_registered, entity_id: user_id, payload: payload}) do
    intended_roles = Map.get(payload, :intended_roles, [])
    business_name = Map.get(payload, :name, "")

    # Trigger: user_registered event with role list
    # Why: only create provider profile if "provider" role requested
    # Outcome: provider profile created or skipped
    if "provider" in intended_roles do
      create_provider_profile_with_retry(user_id, business_name)
    else
      :ignore
    end
  end

  def handle_event(_event), do: :ignore

  defp create_provider_profile_with_retry(user_id, business_name) do
    attrs = %{
      identity_id: user_id,
      business_name: business_name
    }

    operation = fn ->
      Provider.create_provider_profile(attrs)
    end

    context = %{
      operation_name: "create provider profile",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_with_backoff(operation, context)
  end
end
