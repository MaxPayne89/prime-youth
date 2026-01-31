defmodule KlassHero.Participation.Domain.Ports.ForResolvingChildInfo do
  @moduledoc """
  Port for resolving child information from Identity context.

  ## Anti-Corruption Layer

  This port defines the contract for an anti-corruption layer between the
  Participation bounded context and the Identity bounded context.

  The Participation context needs child names and consent-gated safety
  information for session rosters and participation history. This unified
  port replaces the separate name and safety info resolvers to reduce
  cross-context calls per child from 2-3 to at most 2.

  ## Consent Gate

  The adapter implementing this port checks `"provider_data_sharing"` consent
  before returning safety fields:
  - Active consent → returns safety info fields populated
  - No consent → returns safety info fields as nil

  ## Expected Return Values

  - `resolve_child_info/1` - Returns `{:ok, child_info}` or `{:error, :child_not_found}`

  The error `:child_not_found` is translated from Identity context's `:not_found`
  to maintain semantic clarity within Participation context.
  """

  @type child_info :: %{
          first_name: String.t(),
          last_name: String.t(),
          allergies: String.t() | nil,
          support_needs: String.t() | nil,
          emergency_contact: String.t() | nil
        }

  @doc """
  Resolves a child's display info and consent-gated safety data from the Identity context.

  Returns `{:ok, child_info}` with name fields always populated and safety
  fields populated only when consent is active, or `{:error, :child_not_found}`
  if the child doesn't exist.
  """
  @callback resolve_child_info(binary()) ::
              {:ok, child_info()} | {:error, :child_not_found | term()}
end
