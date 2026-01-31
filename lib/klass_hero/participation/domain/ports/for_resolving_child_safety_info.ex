defmodule KlassHero.Participation.Domain.Ports.ForResolvingChildSafetyInfo do
  @moduledoc """
  Port for resolving child safety information from Identity context.

  ## Anti-Corruption Layer

  This port defines the contract for an anti-corruption layer between the
  Participation bounded context and the Identity bounded context.

  Providers need to see safety-critical information (allergies, support needs,
  emergency contact) for children in their session rosters — but only when
  the parent has granted `"provider_data_sharing"` consent.

  ## Consent Gate

  The adapter implementing this port checks consent before returning data:
  - Active consent → returns safety info map
  - No consent → returns `{:ok, nil}` (no data exposed)

  ## Expected Return Values

  - `resolve_child_safety_info/1` - Returns `{:ok, safety_info}` or `{:error, :child_not_found}`

  The error `:child_not_found` is translated from Identity context's `:not_found`
  to maintain semantic clarity within Participation context.
  """

  @type safety_info :: %{
          allergies: String.t() | nil,
          support_needs: String.t() | nil,
          emergency_contact: String.t() | nil
        }

  @doc """
  Resolves a child's safety information from the Identity context.

  Returns `{:ok, safety_info_map}` when parent has granted consent,
  `{:ok, nil}` when no consent exists (data not exposed),
  or `{:error, :child_not_found}` if the child doesn't exist.
  """
  @callback resolve_child_safety_info(binary()) ::
              {:ok, safety_info() | nil} | {:error, :child_not_found | term()}
end
