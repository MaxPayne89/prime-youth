defmodule KlassHero.Messaging.Domain.Models.ParticipantTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.Participant

  describe "new/1" do
    test "creates participant with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        joined_at: DateTime.utc_now()
      }

      assert {:ok, participant} = Participant.new(attrs)
      assert participant.id == attrs.id
      assert participant.conversation_id == attrs.conversation_id
      assert participant.user_id == attrs.user_id
      assert participant.joined_at == attrs.joined_at
      assert is_nil(participant.left_at)
      assert is_nil(participant.last_read_at)
    end

    test "defaults joined_at to now when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate()
      }

      before = DateTime.utc_now()
      {:ok, participant} = Participant.new(attrs)
      after_time = DateTime.utc_now()

      assert DateTime.compare(participant.joined_at, before) in [:gt, :eq]
      assert DateTime.compare(participant.joined_at, after_time) in [:lt, :eq]
    end

    test "returns error when id is missing" do
      attrs = %{
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate()
      }

      assert {:error, ["Missing required fields"]} = Participant.new(attrs)
    end

    test "returns error when conversation_id is empty" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: "",
        user_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Participant.new(attrs)
      assert "conversation_id cannot be empty" in errors
    end

    test "returns error when user_id is empty" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: ""
      }

      assert {:error, errors} = Participant.new(attrs)
      assert "user_id cannot be empty" in errors
    end

    test "returns error when joined_at is not a DateTime" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        joined_at: "not a datetime"
      }

      assert {:error, errors} = Participant.new(attrs)
      assert "joined_at must be a DateTime" in errors
    end
  end

  describe "active?/1" do
    test "returns true when left_at is nil" do
      {:ok, participant} = build_participant()
      assert Participant.active?(participant)
    end

    test "returns false when left_at is set" do
      {:ok, participant} = build_participant()
      participant = %{participant | left_at: DateTime.utc_now()}
      refute Participant.active?(participant)
    end
  end

  describe "left?/1" do
    test "returns false when left_at is nil" do
      {:ok, participant} = build_participant()
      refute Participant.left?(participant)
    end

    test "returns true when left_at is set" do
      {:ok, participant} = build_participant()
      participant = %{participant | left_at: DateTime.utc_now()}
      assert Participant.left?(participant)
    end
  end

  describe "mark_as_read/2" do
    test "sets last_read_at timestamp" do
      {:ok, participant} = build_participant()
      read_at = ~U[2025-01-15 12:00:00Z]

      assert {:ok, updated} = Participant.mark_as_read(participant, read_at)
      assert updated.last_read_at == read_at
    end

    test "uses current time when timestamp not provided" do
      {:ok, participant} = build_participant()
      before = DateTime.utc_now()

      {:ok, updated} = Participant.mark_as_read(participant)

      after_time = DateTime.utc_now()
      assert DateTime.compare(updated.last_read_at, before) in [:gt, :eq]
      assert DateTime.compare(updated.last_read_at, after_time) in [:lt, :eq]
    end
  end

  describe "leave/2" do
    test "sets left_at timestamp" do
      {:ok, participant} = build_participant()
      left_at = ~U[2025-01-15 12:00:00Z]

      assert {:ok, updated} = Participant.leave(participant, left_at)
      assert updated.left_at == left_at
    end

    test "uses current time when timestamp not provided" do
      {:ok, participant} = build_participant()
      before = DateTime.utc_now()

      {:ok, updated} = Participant.leave(participant)

      after_time = DateTime.utc_now()
      assert DateTime.compare(updated.left_at, before) in [:gt, :eq]
      assert DateTime.compare(updated.left_at, after_time) in [:lt, :eq]
    end
  end

  describe "has_unread?/2" do
    test "returns false when last_read_at is nil and no messages" do
      {:ok, participant} = build_participant()
      refute Participant.has_unread?(participant, nil)
    end

    test "returns true when last_read_at is nil but messages exist" do
      {:ok, participant} = build_participant()
      latest_message_at = ~U[2025-01-15 12:00:00Z]
      assert Participant.has_unread?(participant, latest_message_at)
    end

    test "returns true when latest message is after last_read_at" do
      {:ok, participant} = build_participant()
      participant = %{participant | last_read_at: ~U[2025-01-15 10:00:00Z]}
      latest_message_at = ~U[2025-01-15 12:00:00Z]

      assert Participant.has_unread?(participant, latest_message_at)
    end

    test "returns false when latest message is before last_read_at" do
      {:ok, participant} = build_participant()
      participant = %{participant | last_read_at: ~U[2025-01-15 14:00:00Z]}
      latest_message_at = ~U[2025-01-15 12:00:00Z]

      refute Participant.has_unread?(participant, latest_message_at)
    end

    test "returns false when last_read_at equals latest message time" do
      {:ok, participant} = build_participant()
      timestamp = ~U[2025-01-15 12:00:00Z]
      participant = %{participant | last_read_at: timestamp}

      refute Participant.has_unread?(participant, timestamp)
    end

    test "returns false when last_read_at is set but no messages" do
      {:ok, participant} = build_participant()
      participant = %{participant | last_read_at: ~U[2025-01-15 12:00:00Z]}

      refute Participant.has_unread?(participant, nil)
    end
  end

  defp build_participant do
    Participant.new(%{
      id: Ecto.UUID.generate(),
      conversation_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      joined_at: DateTime.utc_now()
    })
  end
end
