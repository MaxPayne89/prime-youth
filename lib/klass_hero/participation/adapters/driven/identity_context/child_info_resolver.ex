defmodule KlassHero.Participation.Adapters.Driven.IdentityContext.ChildInfoResolver do
  @moduledoc """
  Adapter for resolving child info (name + consent-gated safety data) from Identity context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Participation and Identity
  bounded contexts. It:

  1. Fetches the child from Identity context (single call)
  2. Checks `"provider_data_sharing"` consent (single call)
  3. Returns name fields always, safety fields only when consented

  ## Architecture

  ```
  Participation Use Case → ForResolvingChildInfo Port → [THIS ADAPTER] → Identity Public API
       (uses map)           (behaviour contract)       (consent gate)     (owns Child model)
  ```

  The Participation context receives only primitive data (map of strings),
  maintaining proper bounded context isolation per DDD principles.

  ## Error Mapping

  Identity errors are mapped to Participation semantics:

  - `:not_found` (Identity) → `:child_not_found` (Participation)
  - Other errors pass through unchanged
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingChildInfo

  alias KlassHero.Identity

  require Logger

  @consent_type "provider_data_sharing"

  @impl true
  def resolve_child_info(child_id) when is_binary(child_id) do
    case Identity.get_child_by_id(child_id) do
      {:ok, child} ->
        has_consent? = Identity.child_has_active_consent?(child_id, @consent_type)

        child_info = %{
          first_name: child.first_name,
          last_name: child.last_name,
          allergies: if(has_consent?, do: child.allergies),
          support_needs: if(has_consent?, do: child.support_needs),
          emergency_contact: if(has_consent?, do: child.emergency_contact)
        }

        {:ok, child_info}

      {:error, :not_found} ->
        # Map Identity error semantics to Participation semantics
        {:error, :child_not_found}

      {:error, error} ->
        {:error, error}
    end
  rescue
    exception ->
      Logger.warning("Failed to resolve child info",
        child_id: child_id,
        error: Exception.message(exception)
      )

      {:error, :resolution_failed}
  end
end
