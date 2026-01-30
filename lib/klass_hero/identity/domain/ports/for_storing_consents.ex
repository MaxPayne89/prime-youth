defmodule KlassHero.Identity.Domain.Ports.ForStoringConsents do
  @moduledoc """
  Port for consent persistence operations in the Identity bounded context.

  Defines the contract for storing and querying parental consents without
  exposing infrastructure details. Implementations will be provided by
  repository adapters.

  ## Expected Return Values

  - `grant/1` - Returns `{:ok, Consent.t()}` or `{:error, changeset}`
  - `withdraw/1` - Returns `{:ok, Consent.t()}` or `{:error, :not_found}`
  - `get_active_for_child/2` - Returns `{:ok, Consent.t()}` or `{:error, :not_found}`
  - `list_active_by_child/1` - Returns list of consents directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc """
  Grants a new consent record.

  Returns:
  - `{:ok, Consent.t()}` - Consent granted successfully
  - `{:error, changeset}` - Validation failed
  """
  @callback grant(map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Withdraws a consent record by setting withdrawn_at timestamp.

  Returns:
  - `{:ok, Consent.t()}` - Consent withdrawn successfully
  - `{:error, :not_found}` - Consent ID doesn't exist
  - `{:error, changeset}` - Update failed
  """
  @callback withdraw(binary()) :: {:ok, term()} | {:error, :not_found} | {:error, term()}

  @doc """
  Retrieves the active consent for a child and consent type.

  Active means withdrawn_at is nil.

  Returns:
  - `{:ok, Consent.t()}` - Active consent found
  - `{:error, :not_found}` - No active consent exists
  """
  @callback get_active_for_child(binary(), String.t()) ::
              {:ok, term()} | {:error, :not_found}

  @doc """
  Lists all active consents for a given child.

  Returns list of consents (may be empty).
  """
  @callback list_active_by_child(binary()) :: [term()]
end
