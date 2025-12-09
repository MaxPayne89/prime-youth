defmodule PrimeYouth.Support.Adapters.Driven.Persistence.Repositories.ContactRequestRepository do
  @moduledoc """
  Logging-only repository for contact requests.

  This initial implementation logs contact submissions without persisting
  to a database. The repository fulfills the ForContactRequests port contract
  by accepting contact requests and logging them to the application logger.

  ## Use Cases

  - Early development and prototyping
  - Testing without database dependencies
  - Verifying business logic flow
  - Debugging contact form submissions

  ## Architecture

  The repository follows the Adapter pattern in Ports & Adapters architecture:
  - Implements the ForContactRequests behavior
  - Uses Elixir Logger for structured logging
  - Provides proper error handling with rescue clauses
  - Returns contact request on success for verification

  ## Logging Format

  Contact submissions are logged with INFO level in a structured format:

      Contact Form Submission:
      ID: contact_abc123
      Name: John Doe
      Email: john@example.com
      Subject: general
      Message: I have a question...
      Submitted At: 2024-03-15T10:30:00Z

  ## Error Handling

  Errors during logging are caught and logged at ERROR level, returning
  `{:error, :repository_error}` to maintain the port contract.

  ## Future Enhancements

  This repository can be replaced or supplemented with:
  - Database repository using Ecto
  - Email notification repository
  - Multi-channel repository (logs + database + email)
  - Message queue integration for async processing

  ## Example

      contact = %ContactRequest{
        id: "contact_123",
        name: "John Doe",
        email: "john@example.com",
        subject: "general",
        message: "Question about programs",
        submitted_at: DateTime.utc_now()
      }

      {:ok, ^contact} = ContactRequestRepository.submit(contact)
      # => Contact logged to application logger
  """

  @behaviour PrimeYouth.Support.Domain.Ports.ForContactRequests

  alias PrimeYouth.Support.Domain.Models.ContactRequest

  require Logger

  @impl true
  @doc """
  Submits a contact request by logging it to the application logger.

  The function logs the contact request details in a structured format
  at INFO level. This allows tracking of all contact form submissions
  through the application logs.

  ## Parameters

  - `contact_request` - The contact request domain entity to submit

  ## Returns

  - `{:ok, ContactRequest.t()}` - Successfully logged contact request
  - `{:error, :repository_error}` - Logging failed (rare, typically system issues)

  ## Examples

      # Successful submission
      contact = %ContactRequest{id: "contact_123", ...}
      {:ok, ^contact} = submit(contact)

      # Error handling
      {:error, :repository_error} = submit(malformed_contact)
  """
  def submit(%ContactRequest{} = contact_request) do
    Logger.info("""
    Contact Form Submission:
    ID: #{contact_request.id}
    Name: #{contact_request.name}
    Email: #{contact_request.email}
    Subject: #{contact_request.subject}
    Message: #{contact_request.message}
    Submitted At: #{DateTime.to_iso8601(contact_request.submitted_at)}
    """)

    {:ok, contact_request}
  rescue
    error ->
      Logger.error("Failed to log contact request: #{inspect(error)}")
      {:error, :repository_error}
  end
end
