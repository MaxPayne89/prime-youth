defmodule KlassHero.Family.Domain.Ports.ForQueryingConsents do
  @moduledoc """
  Read-only port for querying consents in the Family bounded context.

  Separated from `ForStoringConsents` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Family.Domain.Models.Consent

  @doc """
  Retrieves the active consent for a child and consent type.

  Active means withdrawn_at is nil.

  Returns:
  - `{:ok, Consent.t()}` - Active consent found
  - `{:error, :not_found}` - No active consent exists
  """
  @callback get_active_for_child(binary(), String.t()) ::
              {:ok, Consent.t()} | {:error, :not_found}

  @doc """
  Lists all active consents for a given child.

  Returns list of consents (may be empty).
  """
  @callback list_active_by_child(binary()) :: [Consent.t()]

  @doc """
  Lists active consents of a specific type for multiple children.

  Returns list of consents where child_id is in the given list and consent_type matches.
  Used for batch consent checking across multiple children.
  """
  @callback list_active_for_children([binary()], String.t()) :: [Consent.t()]

  @doc """
  Lists all consents (including withdrawn) for a given child.

  Used for GDPR data export where full audit history is required.
  Returns list of consents ordered by consent_type asc, granted_at desc.
  """
  @callback list_all_by_child(binary()) :: [Consent.t()]
end
