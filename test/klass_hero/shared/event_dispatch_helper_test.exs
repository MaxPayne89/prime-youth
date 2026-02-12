defmodule KlassHero.Shared.EventDispatchHelperTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.EventDispatchHelper

  @context TestContext

  setup do
    # Start a DomainEventBus for the test context
    start_supervised!({DomainEventBus, context: @context})

    :ok
  end

  describe "dispatch/2" do
    test "returns :ok when dispatch succeeds" do
      event = build_event(:test_event)

      assert :ok = EventDispatchHelper.dispatch(event, @context)
    end

    test "returns :ok even when handler fails" do
      DomainEventBus.subscribe(@context, :test_event, fn _event ->
        {:error, :handler_failed}
      end)

      event = build_event(:test_event)

      assert :ok = EventDispatchHelper.dispatch(event, @context)
    end

    test "logs at warning level for normal event dispatch failure" do
      DomainEventBus.subscribe(@context, :test_event, fn _event ->
        {:error, :handler_failed}
      end)

      event = build_event(:test_event, criticality: :normal)

      log =
        capture_log([level: :warning], fn ->
          EventDispatchHelper.dispatch(event, @context)
        end)

      assert log =~ "Event dispatch failed"
      assert log =~ "test_event"
    end

    test "logs at error level for critical event dispatch failure" do
      DomainEventBus.subscribe(@context, :critical_event, fn _event ->
        {:error, :handler_failed}
      end)

      event = build_event(:critical_event, criticality: :critical)

      log =
        capture_log([level: :error], fn ->
          EventDispatchHelper.dispatch(event, @context)
        end)

      assert log =~ "Critical event dispatch failed"
      assert log =~ "critical_event"
    end
  end

  defp build_event(type, opts \\ []) do
    DomainEvent.new(type, 1, :test, %{}, opts)
  end
end
