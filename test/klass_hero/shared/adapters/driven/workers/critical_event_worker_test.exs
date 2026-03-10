defmodule KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  describe "perform/1 with domain events" do
    test "deserializes event and dispatches via CriticalEventDispatcher" do
      event = DomainEvent.new(:test_handled, "agg-1", :test_aggregate, %{data: "value"})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.merge(%{
          "handler" =>
            "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler:handle",
          "context" => "Elixir.KlassHero.TestContext"
        })

      job = %Oban.Job{args: args}
      assert :ok = CriticalEventWorker.perform(job)

      # Verify processed_events row was created
      ref =
        CriticalEventDispatcher.handler_ref(
          {KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler,
           :handle}
        )

      assert Repo.get_by(
               KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent,
               event_id: event.event_id,
               handler_ref: ref
             )
    end

    test "returns error when handler fails (triggers Oban retry)" do
      event = DomainEvent.new(:test_failed, "agg-1", :test_aggregate, %{})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.merge(%{
          "handler" =>
            "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.FailHandler:handle",
          "context" => "Elixir.KlassHero.TestContext"
        })

      job = %Oban.Job{args: args}
      assert {:error, :handler_broke} = CriticalEventWorker.perform(job)
    end
  end

  describe "perform/1 with integration events" do
    test "deserializes integration event and dispatches" do
      event =
        IntegrationEvent.new(:test_integration, :test_context, :entity, "ent-1", %{val: 1})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.put(
          "handler",
          "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler:handle"
        )

      job = %Oban.Job{args: args}
      assert :ok = CriticalEventWorker.perform(job)
    end
  end

  # Test handler modules
  defmodule SuccessHandler do
    def handle(_event), do: :ok
  end

  defmodule FailHandler do
    def handle(_event), do: {:error, :handler_broke}
  end
end
