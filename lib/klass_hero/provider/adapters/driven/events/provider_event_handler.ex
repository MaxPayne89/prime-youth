defmodule KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler do
  @moduledoc """
  Integration event handler for the Provider context.

  Listens to user-related events from the Accounts context and reacts accordingly:

  ## Subscribed Events

  - `:user_registered` - Creates provider profile if "provider" in intended_roles
  - `:user_confirmed` - Compensation path: creates provider profile if not yet created (idempotent)
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
  alias KlassHero.Shared.SubscriptionTiers

  require Logger

  @impl true
  def subscribed_events, do: [:user_registered, :user_confirmed, :user_anonymized]

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
    provider_tier = Map.get(payload, :provider_subscription_tier)

    # Trigger: user_registered event with role list
    # Why: only create provider profile if "provider" role requested
    # Outcome: provider profile created with selected tier or default starter
    if "provider" in intended_roles do
      create_provider_profile_with_retry(user_id, business_name, provider_tier)
    else
      :ignore
    end
  end

  @impl true
  def handle_event(%{event_type: :user_confirmed, entity_id: user_id, payload: payload}) do
    intended_roles = Map.get(payload, :intended_roles, [])
    business_name = Map.get(payload, :name, "")
    provider_tier = Map.get(payload, :provider_subscription_tier)

    # Trigger: user_confirmed event — compensation path for profile creation
    # Why: if user_registered delivery was delayed, this ensures the profile
    #      exists before the user's first authenticated session
    # Outcome: creates profile or returns :ok if already exists (idempotent)
    if "provider" in intended_roles do
      create_provider_profile_with_retry(user_id, business_name, provider_tier)
    else
      :ignore
    end
  end

  def handle_event(_event), do: :ignore

  defp create_provider_profile_with_retry(user_id, business_name, provider_tier) do
    attrs =
      %{
        identity_id: user_id,
        business_name: business_name
      }
      |> maybe_put_tier(provider_tier)

    operation = fn ->
      Provider.create_provider_profile(attrs)
    end

    context = %{
      operation_name: "create provider profile",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_and_normalize(operation, context)
  end

  # Trigger: provider_subscription_tier may be nil or a string like "professional"
  # Why: nil means use default (starter); string needs safe cast to atom for domain model
  # Outcome: attrs includes subscription_tier only when explicitly selected and valid
  defp maybe_put_tier(attrs, nil), do: attrs
  defp maybe_put_tier(attrs, ""), do: attrs

  defp maybe_put_tier(attrs, tier) when is_binary(tier) do
    case SubscriptionTiers.cast_provider_tier(tier) do
      {:ok, valid_tier} ->
        Map.put(attrs, :subscription_tier, valid_tier)

      {:error, :invalid_tier} ->
        Logger.warning("Invalid provider tier in registration event, using default",
          tier: tier,
          identity_id: Map.get(attrs, :identity_id)
        )

        attrs
    end
  end
end
