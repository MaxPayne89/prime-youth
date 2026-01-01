defmodule KlassHero.Support.Domain.Events.SupportEvents do
  @moduledoc """
  Factory module for creating Support domain events.

  Provides convenience functions to create standardized DomainEvent structs
  for support-related events in the Support context.

  ## Events

  - `:contact_request_submitted` - Emitted when a contact form is submitted

  ## Validation

  Event factories perform fail-fast validation on all inputs:

  - **Aggregate validation**: ContactRequest fields must be present and non-empty
  - **Type validation**: All inputs must match expected types

  Validation failures raise `ArgumentError` with descriptive messages.

  ## Usage

      alias KlassHero.Support.Domain.Events.SupportEvents

      # Create a contact_request_submitted event
      event = SupportEvents.contact_request_submitted(contact_request)

      # Create with additional metadata
      event = SupportEvents.contact_request_submitted(contact_request, %{}, correlation_id: "abc-123")

      # Invalid - raises ArgumentError
      contact_request = %ContactRequest{id: nil, name: "John", email: "john@example.com", subject: "general"}
      SupportEvents.contact_request_submitted(contact_request)
      #=> ** (ArgumentError) ContactRequest.id cannot be nil or empty
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Support.Domain.Models.ContactRequest

  @aggregate_type :contact_request

  @doc """
  Creates a `contact_request_submitted` event.

  ## Parameters

  - `contact_request` - The ContactRequest struct that was submitted
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `name` - Submitter's name
  - `email` - Submitter's email address
  - `subject` - Contact request subject/category

  ## Raises

  - `ArgumentError` if `contact_request.id` is nil or empty
  - `ArgumentError` if `contact_request.name` is nil or empty
  - `ArgumentError` if `contact_request.email` is nil or empty
  - `ArgumentError` if `contact_request.subject` is nil or empty

  ## Examples

      iex> contact_request = %ContactRequest{id: "contact_abc123", name: "John", email: "john@example.com", subject: "general", ...}
      iex> event = SupportEvents.contact_request_submitted(contact_request)
      iex> event.event_type
      :contact_request_submitted
      iex> event.payload.name
      "John"
  """
  @spec contact_request_submitted(ContactRequest.t(), map(), keyword()) :: DomainEvent.t()
  def contact_request_submitted(%ContactRequest{} = contact_request, payload \\ %{}, opts \\ []) do
    validate_contact_request!(contact_request)

    base_payload = %{
      name: contact_request.name,
      email: contact_request.email,
      subject: contact_request.subject
    }

    DomainEvent.new(
      :contact_request_submitted,
      contact_request.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  # Private validation functions

  defp validate_contact_request!(%ContactRequest{id: id}) when is_nil(id) or id == "" do
    raise ArgumentError, "ContactRequest.id cannot be nil or empty"
  end

  defp validate_contact_request!(%ContactRequest{name: name}) when is_nil(name) or name == "" do
    raise ArgumentError, "ContactRequest.name cannot be nil or empty"
  end

  defp validate_contact_request!(%ContactRequest{email: email})
       when is_nil(email) or email == "" do
    raise ArgumentError, "ContactRequest.email cannot be nil or empty"
  end

  defp validate_contact_request!(%ContactRequest{subject: subject})
       when is_nil(subject) or subject == "" do
    raise ArgumentError, "ContactRequest.subject cannot be nil or empty"
  end

  defp validate_contact_request!(%ContactRequest{} = contact_request), do: contact_request
end
