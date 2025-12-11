defmodule PrimeYouth.Support.EventPublisher do
  @moduledoc """
  Convenience module for publishing Support context domain events.

  Provides thin wrappers around the generic event publishing infrastructure
  for support-related events. Uses dependency injection to allow testing with
  mock publishers.

  ## Configuration

  The publisher module is configured in application config:

      config :prime_youth, :event_publisher,
        module: PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: PrimeYouth.PubSub

  For tests, configure a test publisher:

      config :prime_youth, :event_publisher,
        module: PrimeYouth.Shared.Adapters.Driven.Events.TestEventPublisher,
        pubsub: PrimeYouth.PubSub

  ## Usage

      alias PrimeYouth.Support.EventPublisher

      # After a contact form is submitted
      EventPublisher.publish_contact_request_submitted(contact_request)
  """

  alias PrimeYouth.Support.Domain.Events.SupportEvents
  alias PrimeYouth.Support.Domain.Models.ContactRequest

  @doc """
  Publishes a `contact_request_submitted` event.

  ## Parameters

  - `contact_request` - The ContactRequest struct that was submitted
  - `opts` - Options passed to event creation
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_contact_request_submitted(contact_request)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_contact_request_submitted(ContactRequest.t(), keyword()) ::
          :ok | {:error, term()}
  def publish_contact_request_submitted(%ContactRequest{} = contact_request, opts \\ []) do
    contact_request
    |> SupportEvents.contact_request_submitted(%{}, opts)
    |> publisher_module().publish()
  end

  defp publisher_module do
    :prime_youth
    |> Application.get_env(:event_publisher, [])
    |> Keyword.get(:module, PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher)
  end
end
