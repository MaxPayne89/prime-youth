defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepositoryTest do
  @moduledoc """
  Integration tests for the BehavioralNoteRepository.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.BehavioralNoteRepository
  alias KlassHero.Participation.Domain.Models.BehavioralNote

  describe "create/1" do
    test "creates a behavioral note" do
      record =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider_id = Ecto.UUID.generate()

      {:ok, note} =
        BehavioralNote.new(%{
          id: Ecto.UUID.generate(),
          participation_record_id: record.id,
          child_id: record.child_id,
          parent_id: record.parent_id,
          provider_id: provider_id,
          content: "Good session"
        })

      assert {:ok, created} = BehavioralNoteRepository.create(note)
      assert created.content == "Good session"
      assert created.status == :pending_approval
      assert created.provider_id == provider_id
    end

    test "returns duplicate_note on unique constraint violation" do
      record =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      provider_id = Ecto.UUID.generate()

      {:ok, note1} =
        BehavioralNote.new(%{
          id: Ecto.UUID.generate(),
          participation_record_id: record.id,
          child_id: record.child_id,
          provider_id: provider_id,
          content: "First note"
        })

      assert {:ok, _} = BehavioralNoteRepository.create(note1)

      {:ok, note2} =
        BehavioralNote.new(%{
          id: Ecto.UUID.generate(),
          participation_record_id: record.id,
          child_id: record.child_id,
          provider_id: provider_id,
          content: "Duplicate note"
        })

      assert {:error, :duplicate_note} = BehavioralNoteRepository.create(note2)
    end
  end

  describe "get_by_id/1" do
    test "returns note when found" do
      schema = insert(:behavioral_note_schema)

      assert {:ok, note} = BehavioralNoteRepository.get_by_id(schema.id)
      assert note.id == schema.id
      assert note.content == schema.content
    end

    test "returns error when not found" do
      assert {:error, :not_found} = BehavioralNoteRepository.get_by_id(Ecto.UUID.generate())
    end
  end

  describe "update/1" do
    test "updates an existing note" do
      schema = insert(:behavioral_note_schema)
      {:ok, note} = BehavioralNoteRepository.get_by_id(schema.id)
      {:ok, approved} = BehavioralNote.approve(note)

      assert {:ok, updated} = BehavioralNoteRepository.update(approved)
      assert updated.status == :approved
      assert updated.reviewed_at != nil
    end

    test "returns error when note not found" do
      note = build(:behavioral_note, id: Ecto.UUID.generate())

      assert {:error, :not_found} = BehavioralNoteRepository.update(note)
    end
  end

  describe "list_pending_by_parent/1" do
    test "returns pending notes for parent" do
      parent = insert(:parent_profile_schema)
      child = insert(:child_schema, parent_id: parent.id)

      record =
        insert(:participation_record_schema,
          child_id: child.id,
          parent_id: parent.id,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      insert(:behavioral_note_schema,
        participation_record_id: record.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :pending_approval
      )

      # Approved note should not appear
      insert(:behavioral_note_schema,
        child_id: child.id,
        parent_id: parent.id,
        status: :approved,
        reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      notes = BehavioralNoteRepository.list_pending_by_parent(parent.id)
      assert length(notes) == 1
      assert hd(notes).status == :pending_approval
    end

    test "returns empty list when no pending notes" do
      parent_id = Ecto.UUID.generate()
      assert [] = BehavioralNoteRepository.list_pending_by_parent(parent_id)
    end
  end

  describe "list_approved_by_child/1" do
    test "returns approved notes for child" do
      schema =
        insert(:behavioral_note_schema,
          status: :approved,
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Pending note for same child should not appear
      insert(:behavioral_note_schema,
        child_id: schema.child_id,
        status: :pending_approval
      )

      notes = BehavioralNoteRepository.list_approved_by_child(schema.child_id)
      assert length(notes) == 1
      assert hd(notes).status == :approved
    end

    test "returns empty list when no approved notes" do
      child_id = Ecto.UUID.generate()
      assert [] = BehavioralNoteRepository.list_approved_by_child(child_id)
    end
  end

  describe "list_by_records_and_provider/2" do
    test "returns notes matching record IDs and provider" do
      provider_id = Ecto.UUID.generate()

      record1 =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      record2 =
        insert(:participation_record_schema,
          status: :checked_in,
          check_in_at: DateTime.utc_now(),
          check_in_by: Ecto.UUID.generate()
        )

      insert(:behavioral_note_schema,
        participation_record_id: record1.id,
        child_id: record1.child_id,
        provider_id: provider_id
      )

      insert(:behavioral_note_schema,
        participation_record_id: record2.id,
        child_id: record2.child_id,
        provider_id: provider_id
      )

      # Note from a different provider — should not appear
      insert(:behavioral_note_schema,
        participation_record_id: record1.id,
        child_id: record1.child_id,
        provider_id: Ecto.UUID.generate()
      )

      notes =
        BehavioralNoteRepository.list_by_records_and_provider(
          [record1.id, record2.id],
          provider_id
        )

      assert length(notes) == 2
      assert Enum.all?(notes, &(&1.provider_id == provider_id))
    end

    test "returns empty list when no matching notes" do
      assert [] =
               BehavioralNoteRepository.list_by_records_and_provider(
                 [Ecto.UUID.generate()],
                 Ecto.UUID.generate()
               )
    end
  end

  describe "get_by_participation_record_and_provider/2" do
    test "returns note when found" do
      schema = insert(:behavioral_note_schema)

      assert {:ok, note} =
               BehavioralNoteRepository.get_by_participation_record_and_provider(
                 schema.participation_record_id,
                 schema.provider_id
               )

      assert note.id == schema.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} =
               BehavioralNoteRepository.get_by_participation_record_and_provider(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate()
               )
    end
  end
end
