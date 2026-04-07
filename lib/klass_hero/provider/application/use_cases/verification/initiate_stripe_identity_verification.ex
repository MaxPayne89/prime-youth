defmodule KlassHero.Provider.Application.UseCases.Verification.InitiateStripeIdentityVerification do
  @moduledoc """
  Initiates a Stripe Identity Verification Session for a provider.

  Creates a session via the Stripe Identity API, stores the session ID on the
  provider profile, and returns the Stripe-hosted URL for the provider to visit.

  ## Idempotency

  If the provider's Stripe Identity status is already `:verified`, returns
  `{:error, :already_verified}` — a new session is not created.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])
  @stripe_port Application.compile_env!(:klass_hero, [:provider, :for_calling_stripe_identity])

  @doc """
  Initiates identity verification for the given provider.

  ## Parameters
  - `provider_id` - The provider profile ID
  - `return_url` - URL Stripe redirects the provider to after completion

  ## Returns
  - `{:ok, %{url: String.t(), session_id: String.t()}}` — Stripe session created
  - `{:error, :not_found}` — Provider profile not found
  - `{:error, :already_verified}` — Identity already verified; no new session needed
  - `{:error, term()}` — Stripe API failure
  """
  def execute(%{provider_id: provider_id, return_url: return_url}) do
    with {:ok, profile} <- @repository.get(provider_id),
         :ok <- guard_not_already_verified(profile),
         {:ok, %{session_id: session_id, url: url}} <-
           @stripe_port.create_verification_session(return_url: return_url),
         {:ok, updated} <- ProviderProfile.stripe_identity_initiated(profile, session_id),
         {:ok, _persisted} <- @repository.update(updated) do
      {:ok, %{url: url, session_id: session_id}}
    end
  end

  defp guard_not_already_verified(%ProviderProfile{stripe_identity_status: :verified}),
    do: {:error, :already_verified}

  defp guard_not_already_verified(_), do: :ok
end
