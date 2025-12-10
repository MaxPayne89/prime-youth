defmodule PrimeYouth.EventTestHelper do
  @moduledoc """
  Test helpers for asserting on domain events.

  Provides convenient functions for testing event publishing in your tests.

  ## Setup

  Add to your test setup:

      setup do
        PrimeYouth.EventTestHelper.setup_test_events()
        :ok
      end

  ## Usage

      test "publishes user_registered event" do
        user = insert(:user)
        EventPublisher.publish_user_registered(user)

        assert_event_published(:user_registered)
        assert_event_published(:user_registered, %{email: user.email})
      end

      test "does not publish events on failure" do
        # ... some operation that fails ...

        assert_no_events_published()
      end
  """

  import ExUnit.Assertions

  alias PrimeYouth.Shared.Adapters.Driven.Events.TestEventPublisher
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  @doc """
  Initializes event collection for the current test.

  Call this in your test setup block.
  """
  @spec setup_test_events() :: :ok
  def setup_test_events do
    TestEventPublisher.setup()
  end

  @doc """
  Clears all collected events.

  Useful if you need to reset event state mid-test.
  """
  @spec clear_events() :: :ok
  def clear_events do
    TestEventPublisher.clear()
  end

  @doc """
  Returns all events published during the test.
  """
  @spec get_published_events() :: [DomainEvent.t()]
  def get_published_events do
    TestEventPublisher.get_events()
  end

  @doc """
  Asserts that an event of the given type was published.

  ## Examples

      assert_event_published(:user_registered)
      assert_event_published(:enrollment_confirmed)
  """
  @spec assert_event_published(atom()) :: DomainEvent.t()
  def assert_event_published(event_type) when is_atom(event_type) do
    events = get_published_events()

    event =
      Enum.find(events, fn %DomainEvent{event_type: type} ->
        type == event_type
      end)

    assert event != nil,
           "Expected event #{inspect(event_type)} to be published.\n" <>
             "Published events: #{format_event_types(events)}"

    event
  end

  @doc """
  Asserts that an event of the given type was published with a payload matching
  the expected fields.

  The payload match is partial - only the specified fields are checked.

  ## Examples

      assert_event_published(:user_registered, %{email: "test@example.com"})
      assert_event_published(:order_placed, %{total: 100, currency: "USD"})
  """
  @spec assert_event_published(atom(), map()) :: DomainEvent.t()
  def assert_event_published(event_type, expected_payload)
      when is_atom(event_type) and is_map(expected_payload) do
    events = get_published_events()

    event =
      Enum.find(events, fn %DomainEvent{event_type: type, payload: payload} ->
        type == event_type && payload_matches?(payload, expected_payload)
      end)

    if event == nil do
      matching_type_events =
        Enum.filter(events, fn %DomainEvent{event_type: type} ->
          type == event_type
        end)

      if matching_type_events == [] do
        flunk(
          "Expected event #{inspect(event_type)} to be published.\n" <>
            "Published events: #{format_event_types(events)}"
        )
      else
        flunk(
          "Expected event #{inspect(event_type)} with payload matching:\n" <>
            "  #{inspect(expected_payload)}\n\n" <>
            "Found #{length(matching_type_events)} event(s) of type #{inspect(event_type)}:\n" <>
            format_event_payloads(matching_type_events)
        )
      end
    end

    event
  end

  @doc """
  Asserts that no events were published.

  ## Examples

      assert_no_events_published()
  """
  @spec assert_no_events_published() :: :ok
  def assert_no_events_published do
    events = get_published_events()

    assert events == [],
           "Expected no events to be published.\n" <>
             "Published events: #{format_event_types(events)}"

    :ok
  end

  @doc """
  Asserts that exactly the given number of events were published.

  ## Examples

      assert_event_count(3)
  """
  @spec assert_event_count(non_neg_integer()) :: :ok
  def assert_event_count(expected_count) when is_integer(expected_count) do
    events = get_published_events()
    actual_count = length(events)

    assert actual_count == expected_count,
           "Expected #{expected_count} event(s) to be published, but got #{actual_count}.\n" <>
             "Published events: #{format_event_types(events)}"

    :ok
  end

  defp payload_matches?(actual, expected) do
    Enum.all?(expected, fn {key, value} ->
      Map.get(actual, key) == value
    end)
  end

  defp format_event_types([]), do: "(none)"

  defp format_event_types(events) do
    events
    |> Enum.map_join(", ", fn %DomainEvent{event_type: type} -> inspect(type) end)
  end

  defp format_event_payloads(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {%DomainEvent{payload: payload}, idx} ->
      "  #{idx}. #{inspect(payload)}"
    end)
  end
end
