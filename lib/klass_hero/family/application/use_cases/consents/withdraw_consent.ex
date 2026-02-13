defmodule KlassHero.Family.Application.UseCases.Consents.WithdrawConsent do
  @moduledoc """
  Use case for withdrawing parental consent.

  Looks up the active consent for a child and consent type, then withdraws it.
  The domain model generates the withdrawn_at timestamp, keeping business logic
  out of the persistence layer.
  """

  alias KlassHero.Family.Domain.Models.Consent

  @repository Application.compile_env!(:klass_hero, [:family, :for_storing_consents])

  @doc """
  Withdraws the active consent for a child and consent type.

  Returns:
  - `{:ok, Consent.t()}` on success (with withdrawn_at set)
  - `{:error, :not_found}` if no active consent exists
  - `{:error, :already_withdrawn}` if consent was already withdrawn
  """
  def execute(child_id, consent_type) when is_binary(child_id) and is_binary(consent_type) do
    with {:ok, consent} <- @repository.get_active_for_child(child_id, consent_type),
         {:ok, withdrawn} <- Consent.withdraw(consent) do
      @repository.withdraw(withdrawn.id, withdrawn.withdrawn_at)
    end
  end
end
