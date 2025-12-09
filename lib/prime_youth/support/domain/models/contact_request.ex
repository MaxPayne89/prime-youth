defmodule PrimeYouth.Support.Domain.Models.ContactRequest do
  @moduledoc """
  Domain model representing a contact form submission.

  This entity represents a user's request for support or information
  through the contact form. It captures all necessary details for
  tracking and responding to contact requests.

  ## Fields

  - `id` - Unique identifier for the contact request
  - `name` - Name of the person submitting the contact request
  - `email` - Email address for response
  - `subject` - Category of the contact request
  - `message` - Detailed message or question
  - `submitted_at` - Timestamp when the request was submitted

  ## Architecture

  This is a pure domain model following DDD principles:
  - Immutable struct with enforced keys
  - No database dependencies (Ecto-independent)
  - Clear type specifications for compile-time checking
  - Can be used across different persistence strategies

  ## Example

      %ContactRequest{
        id: "contact_abc123",
        name: "John Doe",
        email: "john@example.com",
        subject: "general",
        message: "I have a question about your programs.",
        submitted_at: ~U[2024-03-15 10:30:00Z]
      }
  """

  @enforce_keys [:id, :name, :email, :subject, :message, :submitted_at]
  defstruct [:id, :name, :email, :subject, :message, :submitted_at]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          email: String.t(),
          subject: String.t(),
          message: String.t(),
          submitted_at: DateTime.t()
        }
end
