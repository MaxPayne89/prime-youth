defmodule KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandlerTest do
  @moduledoc """
  Tests for ParticipationEventHandler handling of child_data_anonymized events.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "handle_event/1 for :child_data_anonymized" do
    test "anonymizes all behavioral notes for the child" do
      note =
        insert(:behavioral_note_schema,
          content: "Very attentive today",
          status: :approved
        )

      event =
        DomainEvent.new(
          :child_data_anonymized,
          note.child_id,
          :child,
          %{child_id: note.child_id},
          criticality: :critical
        )

      assert :ok == ParticipationEventHandler.handle_event(event)

      reloaded = Repo.get!(BehavioralNoteSchema, note.id)
      assert reloaded.content == "[Removed - account deleted]"
      assert reloaded.status == :rejected
      assert is_nil(reloaded.rejection_reason)
    end

    test "returns :ok when child has no behavioral notes" do
      child_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(
          :child_data_anonymized,
          child_id,
          :child,
          %{child_id: child_id},
          criticality: :critical
        )

      assert :ok == ParticipationEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 for unknown events" do
    test "ignores unrecognized event types" do
      event =
        DomainEvent.new(
          :some_unknown_event,
          Ecto.UUID.generate(),
          :unknown,
          %{}
        )

      assert :ignore == ParticipationEventHandler.handle_event(event)
    end
  end

  describe "subscribed_events/0" do
    test "subscribes to :child_data_anonymized" do
      assert :child_data_anonymized in ParticipationEventHandler.subscribed_events()
    end
  end
end
