defmodule KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandler do
  @moduledoc """
  Consolidated event handler for Identity context.

  This handler listens to user-related events from the Accounts context and
  reacts accordingly:

  ## Subscribed Events

  - `:user_registered` - Auto-creates profiles based on intended_roles:
    - "parent" in roles → creates Parent profile
    - "provider" in roles → creates Provider profile
    - Both roles → creates both profiles

  - `:user_anonymized` - Anonymizes Identity-owned data for the user:
    - Deletes consent records for each child
    - Anonymizes child PII
    - Publishes `child_data_anonymized` per child for downstream contexts

  ## Error Handling

  Operations are handled gracefully with retry logic:
  - Duplicate identity → :ok (profile already exists)
  - Transient errors → Retry once, then log error
  - All errors are logged but don't block event processing
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

  alias KlassHero.Identity
  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  @impl true
  def subscribed_events, do: [:user_registered, :user_anonymized]

  @impl true
  def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id}) do
    anonymize_identity_data_with_retry(user_id)
  end

  @impl true
  def handle_event(%{event_type: :user_registered, aggregate_id: user_id, payload: payload}) do
    intended_roles = Map.get(payload, :intended_roles, [])

    results = []

    results =
      if "parent" in intended_roles do
        [create_parent_profile_with_retry(user_id) | results]
      else
        results
      end

    results =
      if "provider" in intended_roles do
        business_name = Map.get(payload, :name, "")
        [create_provider_profile_with_retry(user_id, business_name) | results]
      else
        results
      end

    case results do
      [] -> :ignore
      _ -> combine_results(results)
    end
  end

  def handle_event(_event), do: :ignore

  # Private functions

  defp create_parent_profile_with_retry(user_id) do
    operation = fn ->
      Identity.create_parent_profile(%{identity_id: user_id})
    end

    context = %{
      operation_name: "create parent profile",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_with_backoff(operation, context)
  end

  defp create_provider_profile_with_retry(user_id, business_name) do
    attrs = %{
      identity_id: user_id,
      business_name: business_name
    }

    operation = fn ->
      Identity.create_provider_profile(attrs)
    end

    context = %{
      operation_name: "create provider profile",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_with_backoff(operation, context)
  end

  defp anonymize_identity_data_with_retry(user_id) do
    operation = fn ->
      Identity.anonymize_data_for_user(user_id)
    end

    context = %{
      operation_name: "anonymize identity data",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    # Trigger: RetryHelpers passes through {:ok, result} but EventSubscriber expects bare :ok
    # Why: handler contract (ForHandlingEvents) returns :ok | {:error, _} | :ignore
    # Outcome: normalize {:ok, _} to :ok for the subscriber
    case RetryHelpers.retry_with_backoff(operation, context) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp combine_results(results) do
    errors = Enum.filter(results, &match?({:error, _}, &1))

    case errors do
      [] -> :ok
      [error | _] -> error
    end
  end
end
