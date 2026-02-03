defmodule KlassHero.Shared.DomainEventBusTest do
  @moduledoc """
  Tests for DomainEventBus dispatch error handling.

  Verifies that handler return values are surfaced correctly:
  - :ok handlers pass through
  - {:error, reason} handlers are collected
  - Crashing handlers are caught and reported
  - Unexpected return values are wrapped
  - Mixed results from multiple handlers are aggregated
  """

  use ExUnit.Case, async: true

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.DomainEventBus

  @test_context __MODULE__.TestContext

  setup do
    bus = start_supervised!({DomainEventBus, context: @test_context})
    %{bus: bus}
  end

  defp build_event(event_type) do
    DomainEvent.new(event_type, "entity-1", :test, %{})
  end

  describe "dispatch/2" do
    test "returns :ok when all handlers succeed" do
      DomainEventBus.subscribe(@test_context, :test_event, fn _event -> :ok end)
      DomainEventBus.subscribe(@test_context, :test_event, fn _event -> :ok end)

      assert :ok = DomainEventBus.dispatch(@test_context, build_event(:test_event))
    end

    test "returns :ok when no handlers are registered" do
      assert :ok = DomainEventBus.dispatch(@test_context, build_event(:unsubscribed_event))
    end

    test "returns error when handler returns {:error, reason}" do
      DomainEventBus.subscribe(@test_context, :failing_event, fn _event ->
        {:error, :publish_failed}
      end)

      assert {:error, [{:error, :publish_failed}]} =
               DomainEventBus.dispatch(@test_context, build_event(:failing_event))
    end

    test "returns error when handler crashes" do
      DomainEventBus.subscribe(@test_context, :crashing_event, fn _event ->
        raise "handler boom"
      end)

      assert {:error, [{:error, {:handler_crashed, %RuntimeError{message: "handler boom"}}}]} =
               DomainEventBus.dispatch(@test_context, build_event(:crashing_event))
    end

    test "wraps unexpected handler return values" do
      DomainEventBus.subscribe(@test_context, :unexpected_event, fn _event ->
        :wrong_return
      end)

      assert {:error, [{:error, {:unexpected_return, :wrong_return}}]} =
               DomainEventBus.dispatch(@test_context, build_event(:unexpected_event))
    end

    test "aggregates failures from multiple handlers" do
      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event -> :ok end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event ->
        {:error, :handler_a_failed}
      end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event -> :ok end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event ->
        raise "handler b boom"
      end)

      assert {:error, failures} =
               DomainEventBus.dispatch(@test_context, build_event(:mixed_event))

      assert length(failures) == 2

      assert Enum.any?(failures, fn
               {:error, :handler_a_failed} -> true
               _ -> false
             end)

      assert Enum.any?(failures, fn
               {:error, {:handler_crashed, %RuntimeError{message: "handler b boom"}}} -> true
               _ -> false
             end)
    end
  end
end
