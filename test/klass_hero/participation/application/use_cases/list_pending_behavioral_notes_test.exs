defmodule KlassHero.Participation.Application.UseCases.ListPendingBehavioralNotesTest do
  @moduledoc """
  Integration tests for ListPendingBehavioralNotes use case.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Application.UseCases.ListPendingBehavioralNotes

  describe "execute/1" do
    test "returns pending notes for a parent" do
      note = insert(:behavioral_note_schema, status: :pending_approval)

      assert {:ok, notes} = ListPendingBehavioralNotes.execute(note.parent_id)
      assert length(notes) == 1
      assert hd(notes).id == note.id
      assert hd(notes).status == :pending_approval
    end

    test "filters out approved and rejected notes" do
      parent_id = Ecto.UUID.generate()

      insert(:behavioral_note_schema,
        parent_id: parent_id,
        status: :pending_approval
      )

      insert(:behavioral_note_schema,
        parent_id: parent_id,
        status: :approved,
        reviewed_at: DateTime.utc_now()
      )

      insert(:behavioral_note_schema,
        parent_id: parent_id,
        status: :rejected,
        rejection_reason: "Please rephrase",
        reviewed_at: DateTime.utc_now()
      )

      assert {:ok, notes} = ListPendingBehavioralNotes.execute(parent_id)
      assert length(notes) == 1
      assert hd(notes).status == :pending_approval
    end

    test "returns {:ok, []} for nonexistent parent" do
      assert {:ok, []} = ListPendingBehavioralNotes.execute(Ecto.UUID.generate())
    end
  end
end
