defmodule KlassHero.Participation.Application.UseCases.RecordCheckInIntegrationTest do
  @moduledoc """
  Integration tests for RecordCheckIn and RecordCheckOut use cases.

  These tests verify the use cases work correctly with real repositories.

  Test Coverage:
  - Check-in transitions record to checked_in status
  - Check-out transitions record to checked_out status
  - Events are published with correct payload structure
  """

  # async: false is REQUIRED because this test modifies global Application config
  use KlassHero.DataCase, async: false

  import KlassHero.Factory

  alias KlassHero.Participation.Application.UseCases.RecordCheckIn
  alias KlassHero.Participation.Application.UseCases.RecordCheckOut

  # Test event publisher that captures published events using Agent
  defmodule TestEventPublisher do
    use Agent

    def start_link(_opts) do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def publish(event) do
      Agent.update(__MODULE__, &[event | &1])
      :ok
    end

    def get_events do
      Agent.get(__MODULE__, & &1) |> Enum.reverse()
    end

    def clear do
      Agent.update(__MODULE__, fn _ -> [] end)
    end
  end

  setup do
    # Store original configs
    original_participation_config = Application.get_env(:klass_hero, :participation)
    original_publisher_config = Application.get_env(:klass_hero, :event_publisher)

    # Start test event publisher
    start_supervised!(TestEventPublisher)

    # Configure real repositories + test publisher
    Application.put_env(:klass_hero, :participation,
      session_repository:
        KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepository,
      participation_repository:
        KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository,
      child_info_resolver:
        KlassHero.Participation.Adapters.Driven.IdentityContext.ChildInfoResolver
    )

    Application.put_env(:klass_hero, :event_publisher,
      module: TestEventPublisher,
      pubsub: KlassHero.PubSub
    )

    on_exit(fn ->
      # Restore original configs
      if original_participation_config do
        Application.put_env(:klass_hero, :participation, original_participation_config)
      else
        Application.delete_env(:klass_hero, :participation)
      end

      if original_publisher_config do
        Application.put_env(:klass_hero, :event_publisher, original_publisher_config)
      else
        Application.delete_env(:klass_hero, :event_publisher)
      end
    end)

    :ok
  end

  describe "RecordCheckIn integration" do
    test "checks in a registered record and publishes event" do
      record_schema = insert(:participation_record_schema)
      provider = insert(:provider_schema)

      {:ok, record} =
        RecordCheckIn.execute(%{
          record_id: record_schema.id,
          checked_in_by: provider.id,
          notes: "Arrived on time"
        })

      assert record.status == :checked_in
      assert record.check_in_by == provider.id
      assert record.check_in_notes == "Arrived on time"
      assert %DateTime{} = record.check_in_at

      events = TestEventPublisher.get_events()
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == :child_checked_in
      assert event.payload.record_id == record_schema.id
      assert event.payload.session_id == record_schema.session_id
      assert event.payload.child_id == record_schema.child_id
      assert event.payload.checked_in_by == provider.id
      assert event.payload.notes == "Arrived on time"
      assert %DateTime{} = event.payload.checked_in_at
    end

    test "checks in with nil notes" do
      record_schema = insert(:participation_record_schema)
      provider = insert(:provider_schema)

      {:ok, record} =
        RecordCheckIn.execute(%{
          record_id: record_schema.id,
          checked_in_by: provider.id
        })

      assert record.status == :checked_in
      assert record.check_in_notes == nil

      events = TestEventPublisher.get_events()
      event = hd(events)
      assert event.payload.notes == nil
    end

    test "returns error for non-existent record" do
      fake_id = Ecto.UUID.generate()

      result =
        RecordCheckIn.execute(%{
          record_id: fake_id,
          checked_in_by: Ecto.UUID.generate()
        })

      assert {:error, :not_found} = result
      assert TestEventPublisher.get_events() == []
    end

    test "returns error when checking in already checked-in record" do
      record_schema =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider = insert(:provider_schema)

      result =
        RecordCheckIn.execute(%{
          record_id: record_schema.id,
          checked_in_by: provider.id
        })

      assert {:error, :invalid_status_transition} = result
      assert TestEventPublisher.get_events() == []
    end
  end

  describe "RecordCheckOut integration" do
    test "checks out a checked-in record and publishes event" do
      record_schema =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider = insert(:provider_schema)

      {:ok, record} =
        RecordCheckOut.execute(%{
          record_id: record_schema.id,
          checked_out_by: provider.id,
          notes: "Picked up by parent"
        })

      assert record.status == :checked_out
      assert record.check_out_by == provider.id
      assert record.check_out_notes == "Picked up by parent"
      assert %DateTime{} = record.check_out_at

      events = TestEventPublisher.get_events()
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == :child_checked_out
      assert event.payload.record_id == record_schema.id
      assert event.payload.session_id == record_schema.session_id
      assert event.payload.child_id == record_schema.child_id
      assert event.payload.checked_out_by == provider.id
      assert event.payload.notes == "Picked up by parent"
      assert %DateTime{} = event.payload.checked_out_at
    end

    test "checks out with nil notes" do
      record_schema =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider = insert(:provider_schema)

      {:ok, record} =
        RecordCheckOut.execute(%{
          record_id: record_schema.id,
          checked_out_by: provider.id
        })

      assert record.status == :checked_out
      assert record.check_out_notes == nil

      events = TestEventPublisher.get_events()
      event = hd(events)
      assert event.payload.notes == nil
    end

    test "returns error for non-existent record" do
      fake_id = Ecto.UUID.generate()

      result =
        RecordCheckOut.execute(%{
          record_id: fake_id,
          checked_out_by: Ecto.UUID.generate()
        })

      assert {:error, :not_found} = result
      assert TestEventPublisher.get_events() == []
    end

    test "returns error when checking out a registered record" do
      record_schema = insert(:participation_record_schema)
      provider = insert(:provider_schema)

      result =
        RecordCheckOut.execute(%{
          record_id: record_schema.id,
          checked_out_by: provider.id
        })

      assert {:error, :invalid_status_transition} = result
      assert TestEventPublisher.get_events() == []
    end
  end

  describe "end-to-end check-in/check-out flow" do
    test "complete participation cycle" do
      record_schema = insert(:participation_record_schema)
      provider = insert(:provider_schema)

      # Check in
      {:ok, check_in_record} =
        RecordCheckIn.execute(%{
          record_id: record_schema.id,
          checked_in_by: provider.id,
          notes: "Morning arrival"
        })

      assert check_in_record.status == :checked_in

      # Check out
      {:ok, check_out_record} =
        RecordCheckOut.execute(%{
          record_id: record_schema.id,
          checked_out_by: provider.id,
          notes: "Evening pickup"
        })

      assert check_out_record.status == :checked_out

      # Verify both events were published
      events = TestEventPublisher.get_events()
      assert length(events) == 2

      [check_in_event, check_out_event] = events

      assert check_in_event.event_type == :child_checked_in
      assert check_in_event.payload.notes == "Morning arrival"

      assert check_out_event.event_type == :child_checked_out
      assert check_out_event.payload.notes == "Evening pickup"
    end
  end
end
