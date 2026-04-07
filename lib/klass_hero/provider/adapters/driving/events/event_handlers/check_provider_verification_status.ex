defmodule KlassHero.Provider.Adapters.Driving.Events.EventHandlers.CheckProviderVerificationStatus do
  @moduledoc """
  Domain event handler that bridges document approval and Stripe Identity to provider verification.

  Auto-verifies a provider when ALL of the following are true:
  1. All verification documents are approved (non-empty list, all status :approved)
  2. Stripe Identity verification is complete (stripe_identity_status == :verified)

  When a document is rejected, checks if the provider was previously verified.
  If so, auto-unverifies via UnverifyProvider use case.

  Registered on the Provider DomainEventBus for:
  - :verification_document_approved
  - :verification_document_rejected
  - :stripe_identity_verified
  - :stripe_identity_failed
  """

  alias KlassHero.Provider.Application.UseCases.Providers.UnverifyProvider
  alias KlassHero.Provider.Application.UseCases.Providers.VerifyProvider
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @doc_repository Application.compile_env!(:klass_hero, [
                    :provider,
                    :for_storing_verification_documents
                  ])

  @profile_repository Application.compile_env!(:klass_hero, [
                        :provider,
                        :for_storing_provider_profiles
                      ])

  @doc """
  Handles verification document and Stripe Identity domain events.

  For :verification_document_approved — checks all docs AND Stripe Identity; verifies provider if both gates pass.
  For :verification_document_rejected — unverifies provider if currently verified.
  For :stripe_identity_verified — checks all docs; verifies provider if both gates pass.
  For :stripe_identity_failed — no-op (status already persisted; UI reads it).
  """
  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :verification_document_approved, payload: payload}) do
    %{provider_id: provider_id, reviewer_id: reviewer_id} = payload

    # Trigger: a document was just approved
    # Why: provider should be auto-verified when ALL docs approved AND Stripe Identity verified
    # Outcome: if both gates pass, VerifyProvider is called (publishes integration event)
    with {:ok, docs} <- @doc_repository.get_by_provider(provider_id),
         {:ok, profile} <- @profile_repository.get(provider_id),
         true <- all_approved?(docs) && ProviderProfile.stripe_identity_verified?(profile) do
      auto_verify(provider_id, reviewer_id)
    else
      # Trigger: docs not all approved or Stripe Identity not yet verified
      # Why: both gates required; partial approval is not sufficient
      # Outcome: no action needed
      false -> :ok
      {:error, reason} -> {:error, {:verification_check_failed, reason}}
    end
  end

  def handle(%DomainEvent{event_type: :verification_document_rejected, payload: payload}) do
    %{provider_id: provider_id, reviewer_id: reviewer_id} = payload

    # Trigger: a document was rejected
    # Why: a verified provider with a rejected doc violates the invariant
    # Outcome: if provider was verified, UnverifyProvider is called
    with {:ok, profile} <- @profile_repository.get(provider_id),
         true <- profile.verified do
      case UnverifyProvider.execute(%{provider_id: provider_id, admin_id: reviewer_id}) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Auto-unverify failed for provider #{provider_id}: #{inspect(reason)}")
          :ok
      end
    else
      # Trigger: provider not verified — rejection is expected/normal
      # Why: no invariant violation when unverified provider has rejected doc
      # Outcome: no action needed
      false -> :ok
      {:error, reason} -> {:error, {:unverification_check_failed, reason}}
    end
  end

  def handle(%DomainEvent{event_type: :stripe_identity_verified, payload: payload}) do
    %{provider_id: provider_id} = payload

    # Trigger: Stripe Identity verified (and 18+ age gate passed)
    # Why: identity is now confirmed; check if documents are also all approved
    # Outcome: if all docs approved too, auto-verify provider using "system" as reviewer
    with {:ok, docs} <- @doc_repository.get_by_provider(provider_id),
         true <- all_approved?(docs) do
      auto_verify(provider_id, "system")
    else
      false -> :ok
      {:error, reason} -> {:error, {:verification_check_failed, reason}}
    end
  end

  def handle(%DomainEvent{event_type: :stripe_identity_failed}) do
    # Trigger: Stripe Identity verification failed or was canceled
    # Why: status is already persisted on the provider profile; UI reads it directly
    # Outcome: no action needed at the domain level
    :ok
  end

  defp auto_verify(provider_id, reviewer_id) do
    case VerifyProvider.execute(%{provider_id: provider_id, admin_id: reviewer_id}) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Auto-verify failed for provider #{provider_id}: #{inspect(reason)}")
        :ok
    end
  end

  # Trigger: need to check if every document for a provider has been approved
  # Why: provider verification requires ALL documents reviewed and approved
  # Outcome: returns true only when list is non-empty and every doc is :approved
  defp all_approved?([]), do: false
  defp all_approved?(docs), do: Enum.all?(docs, &(&1.status == :approved))
end
