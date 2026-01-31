defmodule KlassHero.Participation.Adapters.Driven.IdentityContext.ChildSafetyInfoResolver do
  @moduledoc """
  Adapter for resolving consent-gated child safety information from Identity context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Participation and Identity
  bounded contexts. It:

  1. Checks if the parent has granted `"provider_data_sharing"` consent for the child
  2. If consented, fetches the child from Identity context and extracts safety fields
  3. If not consented, returns `nil` (no safety data exposed to provider)

  ## Architecture

  ```
  Participation Use Case → ForResolvingChildSafetyInfo Port → [THIS ADAPTER] → Identity Public API
       (uses map/nil)        (behaviour contract)            (consent gate)      (owns Child model)
  ```

  The Participation context receives only primitive data (map of strings),
  maintaining proper bounded context isolation per DDD principles.

  ## Error Mapping

  Identity errors are mapped to Participation semantics:

  - `:not_found` (Identity) → `:child_not_found` (Participation)
  - Other errors pass through unchanged
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingChildSafetyInfo

  alias KlassHero.Identity

  @consent_type "provider_data_sharing"

  @impl true
  def resolve_child_safety_info(child_id) when is_binary(child_id) do
    # Trigger: parent has not granted provider_data_sharing consent
    # Why: consent gates visibility, not storage — GDPR data minimization
    # Outcome: provider sees only child name, no safety details
    if Identity.child_has_active_consent?(child_id, @consent_type) do
      fetch_safety_info(child_id)
    else
      {:ok, nil}
    end
  end

  defp fetch_safety_info(child_id) do
    case Identity.get_child_by_id(child_id) do
      {:ok, child} ->
        safety_info = %{
          allergies: child.allergies,
          support_needs: child.support_needs,
          emergency_contact: child.emergency_contact
        }

        {:ok, safety_info}

      {:error, :not_found} ->
        # Map Identity error semantics to Participation semantics
        {:error, :child_not_found}

      {:error, error} ->
        {:error, error}
    end
  end
end
