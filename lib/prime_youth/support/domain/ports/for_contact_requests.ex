defmodule PrimeYouth.Support.Domain.Ports.ForContactRequests do
  @moduledoc """
  Port for managing contact requests in the Support context.

  This port defines the contract that any persistence adapter must implement
  to provide contact request submission capabilities. The port follows the
  Hexagonal Architecture pattern, allowing the domain layer to remain
  independent of specific infrastructure implementations.

  ## Repository Operations

  - `submit/1` - Submit a contact request to the repository

  ## Error Handling

  All operations return `{:ok, result}` tuples on success or `{:error, reason}`
  tuples on failure. Error reasons are defined as types for compile-time checking.

  ## Architecture

  The port is implemented by infrastructure adapters such as:
  - Logging-based repository (current implementation)
  - Database repository (future enhancement)
  - Email-sending repository (future enhancement)
  - Multi-channel repository (logs + database + email)

  ## Example Implementation

      defmodule MyApp.Support.Adapters.LoggingRepository do
        @behaviour PrimeYouth.Support.Domain.Ports.ForContactRequests

        def submit(contact_request) do
          Logger.info("Contact: \#{contact_request.email}")
          {:ok, contact_request}
        end
      end

  ## Example Usage

      repository = Application.get_env(:prime_youth, :support)[:repository]
      {:ok, submitted} = repository.submit(contact_request)
  """

  alias PrimeYouth.Support.Domain.Models.ContactRequest

  @type submit_error :: :repository_unavailable | :repository_error

  @doc """
  Submits a contact request to the repository.

  The repository implementation determines what happens with the contact
  request - it may be logged, stored in a database, sent via email, or
  any combination of these actions.

  Parameters:
  - `contact_request` - The contact request domain entity to submit

  Returns:
  - `{:ok, ContactRequest.t()}` - Successfully submitted
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error

  ## Examples

      # Successful submission
      contact = %ContactRequest{id: "contact_123", ...}
      {:ok, ^contact} = repository.submit(contact)

      # Repository unavailable
      {:error, :repository_unavailable} = repository.submit(contact)

      # General repository error
      {:error, :repository_error} = repository.submit(contact)
  """
  @callback submit(ContactRequest.t()) :: {:ok, ContactRequest.t()} | {:error, submit_error()}
end
