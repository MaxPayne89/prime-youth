defmodule KlassHero.Participation.Application.UseCases.ReviewBehavioralNoteTest do
  @moduledoc """
  Integration tests for ReviewBehavioralNote use case.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Application.UseCases.ReviewBehavioralNote

  describe "execute/1 - approve" do
    test "approves a pending behavioral note" do
      schema = insert(:behavioral_note_schema, status: :pending_approval)

      assert {:ok, note} =
               ReviewBehavioralNote.execute(%{note_id: schema.id, decision: :approve})

      assert note.status == :approved
      assert note.reviewed_at != nil
    end

    test "returns error for non-existent note" do
      assert {:error, :not_found} =
               ReviewBehavioralNote.execute(%{
                 note_id: Ecto.UUID.generate(),
                 decision: :approve
               })
    end

    test "returns error for already approved note" do
      schema =
        insert(:behavioral_note_schema,
          status: :approved,
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :invalid_status_transition} =
               ReviewBehavioralNote.execute(%{note_id: schema.id, decision: :approve})
    end
  end

  describe "execute/1 - reject" do
    test "rejects a pending behavioral note with reason" do
      schema = insert(:behavioral_note_schema, status: :pending_approval)

      assert {:ok, note} =
               ReviewBehavioralNote.execute(%{
                 note_id: schema.id,
                 decision: :reject,
                 reason: "Not accurate"
               })

      assert note.status == :rejected
      assert note.rejection_reason == "Not accurate"
      assert note.reviewed_at != nil
    end

    test "rejects a pending behavioral note without reason" do
      schema = insert(:behavioral_note_schema, status: :pending_approval)

      assert {:ok, note} =
               ReviewBehavioralNote.execute(%{note_id: schema.id, decision: :reject})

      assert note.status == :rejected
      assert note.rejection_reason == nil
    end
  end
end
