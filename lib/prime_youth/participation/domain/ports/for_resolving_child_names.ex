defmodule PrimeYouth.Participation.Domain.Ports.ForResolvingChildNames do
  @moduledoc """
  Port for resolving child names from Identity context.

  ## Anti-Corruption Layer

  This port defines the contract for an anti-corruption layer between the
  Participation bounded context and the Identity bounded context.

  The Participation context needs to display child names in session rosters and
  participation history, but it should not directly depend on Identity context models.

  ## Expected Return Values

  - `resolve_child_name/1` - Returns `{:ok, name}` or `{:error, :child_not_found}`

  The error `:child_not_found` is translated from Identity context's `:not_found`
  to maintain semantic clarity within Participation context.
  """

  @doc """
  Resolves a child's display name from the Identity context.

  Returns `{:ok, full_name}` where `full_name` is a string like "Jane Doe",
  or `{:error, :child_not_found}` if the child doesn't exist.
  """
  @callback resolve_child_name(binary()) ::
              {:ok, String.t()} | {:error, :child_not_found | term()}
end
