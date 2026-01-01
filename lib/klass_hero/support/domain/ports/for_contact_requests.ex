defmodule KlassHero.Support.Domain.Ports.ForContactRequests do
  @moduledoc """
  Port for managing contact requests in the Support context.

  This port defines the contract that any persistence adapter must implement
  to provide contact request submission capabilities. The port follows the
  Hexagonal Architecture pattern, allowing the domain layer to remain
  independent of specific infrastructure implementations.

  ## Repository Operations

  - `submit/1` - Submit a contact request to the repository

  ## Expected Return Values

  - `submit/1` - Returns `{:ok, ContactRequest.t()}` on success

  Infrastructure errors are not caught - they crash and are handled by
  the supervision tree.

  ## Architecture

  The port is implemented by infrastructure adapters such as:
  - Logging-based repository (current implementation)
  - Database repository (future enhancement)
  - Email-sending repository (future enhancement)
  - Multi-channel repository (logs + database + email)
  """

  @doc """
  Submits a contact request to the repository.

  The repository implementation determines what happens with the contact
  request - it may be logged, stored in a database, sent via email, or
  any combination of these actions.

  Returns:
  - `{:ok, ContactRequest.t()}` - Successfully submitted
  """
  @callback submit(term()) :: {:ok, term()}
end
