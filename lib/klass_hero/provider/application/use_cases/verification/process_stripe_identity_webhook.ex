defmodule KlassHero.Provider.Application.UseCases.Verification.ProcessStripeIdentityWebhook do
  @moduledoc """
  Processes the outcome of a Stripe Identity Verification Session webhook.

  Called by the StripeWebhookController after signature verification. Looks up
  the provider by session ID, applies the 18+ age gate, persists the result, and
  dispatches domain events so that `CheckProviderVerificationStatus` can react.

  ## Age Gate

  When Stripe reports `:verified`, the `verified_outputs.dob` field is checked.
  If the calculated age is under 18, the effective status is set to `:requires_input`
  (the provider must contact support — Stripe does not allow re-verification of the
  same session once verified). If no DOB is returned by Stripe, the gate passes.

  ## PubSub notification

  After persisting, a message is broadcast on the provider's personal PubSub topic
  so that any connected dashboard LiveView can update in real time without a page reload.
  """

  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Provider
  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])

  @doc """
  Processes the Stripe Identity webhook outcome.

  ## Parameters
  - `session_id` - Stripe session ID (used to look up the provider)
  - `status` - `:verified`, `:requires_input`, or `:canceled`
  - `verified_outputs` - Map of outputs from Stripe (may be nil)
  """
  def execute(%{session_id: session_id, status: status, verified_outputs: verified_outputs}) do
    with {:ok, profile} <- @repository.get_by_stripe_session_id(session_id) do
      effective_status = resolve_effective_status(status, verified_outputs, profile)

      with {:ok, updated} <-
             ProviderProfile.record_stripe_identity_result(profile, session_id, effective_status),
           {:ok, persisted} <- @repository.update(updated) do
        dispatch_event(persisted, effective_status)
        broadcast_status_update(persisted)
        :ok
      end
    end
  end

  defp resolve_effective_status(:verified, verified_outputs, profile) do
    dob = verified_outputs && get_in(verified_outputs, ["dob"])

    if dob && !age_gate_passes?(dob) do
      Logger.warning("Stripe Identity: provider failed 18+ age gate",
        provider_id: profile.id,
        stripe_session_id: profile.stripe_identity_session_id
      )

      :requires_input
    else
      :verified
    end
  end

  defp resolve_effective_status(status, _verified_outputs, _profile), do: status

  defp age_gate_passes?(nil), do: true

  defp age_gate_passes?(%{"year" => year, "month" => month, "day" => day}) do
    case Date.new(year, month, day) do
      {:ok, dob} ->
        today = Date.utc_today()
        had_birthday_this_year = {today.month, today.day} >= {dob.month, dob.day}
        age = today.year - dob.year - if(had_birthday_this_year, do: 0, else: 1)
        age >= 18

      {:error, reason} ->
        Logger.warning("Stripe Identity: invalid DOB in verified_outputs — allowing through",
          reason: inspect(reason)
        )

        true
    end
  end

  defp age_gate_passes?(_), do: true

  defp dispatch_event(profile, :verified) do
    event = ProviderEvents.stripe_identity_verified(profile)
    DomainEventBus.dispatch(@context, event)
  end

  defp dispatch_event(profile, status) when status in [:requires_input, :canceled] do
    event = ProviderEvents.stripe_identity_failed(profile, status)
    DomainEventBus.dispatch(@context, event)
  end

  defp broadcast_status_update(profile) do
    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "provider:#{profile.id}:stripe_identity",
      {:stripe_identity_updated, %{status: profile.stripe_identity_status}}
    )
  end
end
