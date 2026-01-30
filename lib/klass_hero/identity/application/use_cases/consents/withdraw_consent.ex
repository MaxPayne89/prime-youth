defmodule KlassHero.Identity.Application.UseCases.Consents.WithdrawConsent do
  @moduledoc """
  Use case for withdrawing parental consent.

  Looks up the active consent for a child and consent type, then withdraws it.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_consents])

  @doc """
  Withdraws the active consent for a child and consent type.

  Returns:
  - `{:ok, Consent.t()}` on success (with withdrawn_at set)
  - `{:error, :not_found}` if no active consent exists
  """
  def execute(child_id, consent_type) when is_binary(child_id) and is_binary(consent_type) do
    with {:ok, consent} <- @repository.get_active_for_child(child_id, consent_type) do
      @repository.withdraw(consent.id)
    end
  end
end
