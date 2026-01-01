defmodule KlassHero.Support.EventPublisher do
  @moduledoc """
  Convenience module for publishing Support context domain events.

  Provides thin wrappers around the generic event publishing infrastructure
  for support-related events. Uses dependency injection to allow testing with
  mock publishers.

  ## Configuration

  The publisher module is configured in application config:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: KlassHero.PubSub

  For tests, configure a test publisher:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.TestEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      alias KlassHero.Support.EventPublisher

      # After a contact form is submitted
      EventPublisher.publish_contact_request_submitted(contact_request)
  """

  alias KlassHero.Support.Domain.Events.SupportEvents
  alias KlassHero.Support.Domain.Models.ContactRequest

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
    :klass_hero
    |> Application.get_env(:event_publisher, [])
    |> Keyword.get(:module, KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher)
  end
end
