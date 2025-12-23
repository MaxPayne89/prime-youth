defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckInIntegrationTest do
  @moduledoc """
  Integration tests for RecordCheckIn and RecordCheckOut use cases.

  These tests verify the integration between the Attendance context and
  the Family context for child name resolution in event publishing.

  ## Database Constraints
  The attendance_records table has a foreign key constraint on child_id
  referencing the children table, ensuring data integrity. This means:
  - Attendance records can only be created for existing children
  - The "Unknown Child" fallback is a defensive pattern for edge cases
    (like DB lookup errors during name resolution), not a normal flow

  Test Coverage:
  - Check-in publishes event with correct child name from Family context
  - Check-out publishes event with correct child name from Family context
  - Child name is correctly resolved from database
  """

  # async: false is REQUIRED because this test modifies global Application config
  use PrimeYouth.DataCase, async: false

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckIn
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckOut
  alias PrimeYouth.Family.Domain.Models.Child
  alias PrimeYouth.Repo

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
    original_attendance_config = Application.get_env(:prime_youth, :attendance)
    original_family_config = Application.get_env(:prime_youth, :family)
    original_publisher_config = Application.get_env(:prime_youth, :event_publisher)

    # Start test event publisher
    start_supervised!(TestEventPublisher)

    # Configure real repositories + test publisher
    Application.put_env(:prime_youth, :attendance,
      session_repository:
        PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.SessionRepository,
      attendance_repository:
        PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository
    )

    Application.put_env(:prime_youth, :family,
      repository:
        PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository,
      child_repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository
    )

    Application.put_env(:prime_youth, :event_publisher,
      module: TestEventPublisher,
      pubsub: PrimeYouth.PubSub
    )

    on_exit(fn ->
      # Restore original configs
      if original_attendance_config do
        Application.put_env(:prime_youth, :attendance, original_attendance_config)
      else
        Application.delete_env(:prime_youth, :attendance)
      end

      if original_family_config do
        Application.put_env(:prime_youth, :family, original_family_config)
      else
        Application.delete_env(:prime_youth, :family)
      end

      if original_publisher_config do
        Application.put_env(:prime_youth, :event_publisher, original_publisher_config)
      else
        Application.delete_env(:prime_youth, :event_publisher)
      end
    end)

    :ok
  end

  describe "RecordCheckIn with Family context integration" do
    test "publishes event with correct child name when child exists" do
      # Insert child using factory (which also creates parent)
      child_schema = insert(:child_schema, first_name: "Emma", last_name: "Johnson")
      session = insert_session()
      provider = insert(:provider_schema)

      {:ok, _record} =
        RecordCheckIn.execute(session.id, child_schema.id, provider.id, "Arrived on time")

      events = TestEventPublisher.get_events()
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == :child_checked_in
      assert event.payload.child_id == child_schema.id
      assert event.payload.child_name == "Emma Johnson"
      assert event.payload.check_in_notes == "Arrived on time"
      assert event.payload.check_in_by == provider.id
    end

    test "publishes event with correct session_id" do
      child_schema = insert(:child_schema, first_name: "Liam", last_name: "Wilson")
      session = insert_session()
      provider = insert(:provider_schema)

      {:ok, _record} = RecordCheckIn.execute(session.id, child_schema.id, provider.id, nil)

      events = TestEventPublisher.get_events()
      event = hd(events)
      assert event.payload.session_id == session.id
    end

    test "publishes event with empty check_in_notes when none provided" do
      child_schema = insert(:child_schema)
      session = insert_session()
      provider = insert(:provider_schema)

      {:ok, _record} = RecordCheckIn.execute(session.id, child_schema.id, provider.id)

      events = TestEventPublisher.get_events()
      event = hd(events)
      # Notes default to empty string when nil
      assert event.payload.check_in_notes == ""
    end
  end

  describe "RecordCheckOut with Family context integration" do
    test "publishes event with correct child name when child exists" do
      # Insert child using factory
      child_schema = insert(:child_schema, first_name: "Oliver", last_name: "Williams")
      session = insert_session()
      provider = insert(:provider_schema)

      # First check in the child
      {:ok, _check_in_record} =
        RecordCheckIn.execute(session.id, child_schema.id, provider.id, nil)

      # Clear events from check-in
      TestEventPublisher.clear()

      # Now check out
      {:ok, _record} =
        RecordCheckOut.execute(session.id, child_schema.id, provider.id, "Picked up by parent")

      events = TestEventPublisher.get_events()
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == :child_checked_out
      assert event.payload.child_id == child_schema.id
      assert event.payload.child_name == "Oliver Williams"
      assert event.payload.check_out_notes == "Picked up by parent"
      assert event.payload.check_out_by == provider.id
    end

    test "publishes event with duration_seconds calculated" do
      child_schema = insert(:child_schema, first_name: "Ava", last_name: "Brown")
      session = insert_session()
      provider = insert(:provider_schema)

      # Check in
      {:ok, _check_in_record} =
        RecordCheckIn.execute(session.id, child_schema.id, provider.id, nil)

      TestEventPublisher.clear()

      # Check out immediately (duration will be >= 0)
      {:ok, _record} =
        RecordCheckOut.execute(session.id, child_schema.id, provider.id, nil)

      events = TestEventPublisher.get_events()
      event = hd(events)

      assert is_integer(event.payload.duration_seconds)
      assert event.payload.duration_seconds >= 0
    end

    test "publishes event with check_in_at and check_out_at timestamps" do
      child_schema = insert(:child_schema)
      session = insert_session()
      provider = insert(:provider_schema)

      {:ok, _check_in_record} =
        RecordCheckIn.execute(session.id, child_schema.id, provider.id, nil)

      TestEventPublisher.clear()

      {:ok, _record} =
        RecordCheckOut.execute(session.id, child_schema.id, provider.id, nil)

      events = TestEventPublisher.get_events()
      event = hd(events)

      assert %DateTime{} = event.payload.check_in_at
      assert %DateTime{} = event.payload.check_out_at
      assert DateTime.compare(event.payload.check_out_at, event.payload.check_in_at) in [:gt, :eq]
    end
  end

  describe "Child.full_name/1 integration verification" do
    test "child full name is correctly resolved from database" do
      # Insert child with specific names
      child_schema = insert(:child_schema, first_name: "Sophia", last_name: "Martinez")

      # Fetch using the repository to verify integration
      child_repository = Application.get_env(:prime_youth, :family)[:child_repository]
      {:ok, child} = child_repository.get_by_id(child_schema.id)

      assert %Child{} = child
      assert Child.full_name(child) == "Sophia Martinez"
    end

    test "child repository correctly maps all fields from database" do
      child_schema =
        insert(:child_schema,
          first_name: "Noah",
          last_name: "Davis",
          date_of_birth: ~D[2020-03-15],
          notes: "Allergic to peanuts"
        )

      child_repository = Application.get_env(:prime_youth, :family)[:child_repository]
      {:ok, child} = child_repository.get_by_id(child_schema.id)

      assert child.first_name == "Noah"
      assert child.last_name == "Davis"
      assert child.date_of_birth == ~D[2020-03-15]
      assert child.notes == "Allergic to peanuts"
      assert child.parent_id == child_schema.parent_id
    end
  end

  describe "end-to-end check-in/check-out flow" do
    test "complete attendance cycle publishes both events correctly" do
      child_schema = insert(:child_schema, first_name: "Isabella", last_name: "Garcia")
      session = insert_session()
      provider = insert(:provider_schema)

      # Check in
      {:ok, check_in_record} =
        RecordCheckIn.execute(session.id, child_schema.id, provider.id, "Morning arrival")

      assert check_in_record.status == :checked_in

      # Check out
      {:ok, check_out_record} =
        RecordCheckOut.execute(session.id, child_schema.id, provider.id, "Evening pickup")

      assert check_out_record.status == :checked_out

      # Verify both events were published with correct child name
      events = TestEventPublisher.get_events()
      assert length(events) == 2

      [check_in_event, check_out_event] = events

      assert check_in_event.event_type == :child_checked_in
      assert check_in_event.payload.child_name == "Isabella Garcia"
      assert check_in_event.payload.check_in_notes == "Morning arrival"

      assert check_out_event.event_type == :child_checked_out
      assert check_out_event.payload.child_name == "Isabella Garcia"
      assert check_out_event.payload.check_out_notes == "Evening pickup"
    end
  end

  # Helper to insert a program session directly
  # First inserts a program (required by foreign key), then creates the session
  defp insert_session do
    # Insert a program first (required by foreign key constraint)
    program_schema = insert(:program_schema)

    attrs = %{
      program_id: program_schema.id,
      session_date: Date.utc_today(),
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      max_capacity: 20,
      status: "scheduled"
    }

    %ProgramSessionSchema{}
    |> ProgramSessionSchema.changeset(attrs)
    |> Repo.insert!()
  end
end
