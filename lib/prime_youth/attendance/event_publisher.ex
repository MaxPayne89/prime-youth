defmodule PrimeYouth.Attendance.EventPublisher do
  @moduledoc """
  Convenience module for publishing Attendance context domain events.

  Provides a simple wrapper around the generic event publishing infrastructure.
  Uses dependency injection to allow testing with mock publishers.

  ## Configuration

  The publisher module is configured in application config:

      config :prime_youth, :event_publisher,
        module: PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: PrimeYouth.PubSub

  ## Usage

      alias PrimeYouth.Attendance.EventPublisher

      event = AttendanceEvents.child_checked_in(...)
      EventPublisher.publish(event)
  """

  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  @doc """
  Publishes a domain event to the configured event publisher.

  ## Parameters

  - `event` - The DomainEvent struct to publish

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure

  ## Examples

      event = AttendanceEvents.child_checked_in(record, child_name, ...)
      EventPublisher.publish(event)
  """
  def publish(%DomainEvent{} = event) do
    publisher_module().publish(event)
  end

  defp publisher_module do
    Application.get_env(:prime_youth, :event_publisher, [])
    |> Keyword.get(:module, PrimeYouth.Shared.Adapters.Driven.Events.PubSubEventPublisher)
  end
end
