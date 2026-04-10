defmodule KlassHero.Participation.Adapters.Driven.Persistence.Mappers.BehavioralNoteMapperTest do
  @moduledoc """
  Unit tests for BehavioralNoteMapper.

  Tests schema-to-domain and domain-to-persistence mappings.
  No database required — schemas and domain structs are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.BehavioralNoteMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema
  alias KlassHero.Participation.Domain.Models.BehavioralNote

  @note_id Ecto.UUID.generate()
  @record_id Ecto.UUID.generate()
  @child_id Ecto.UUID.generate()
  @parent_id Ecto.UUID.generate()
  @provider_id Ecto.UUID.generate()
  @submitted_at ~U[2026-01-15 10:00:00Z]
  @reviewed_at ~U[2026-01-15 11:00:00Z]
  @inserted_at ~U[2026-01-15 09:00:00Z]
  @updated_at ~U[2026-01-15 09:30:00Z]

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: @note_id,
      participation_record_id: @record_id,
      child_id: @child_id,
      parent_id: @parent_id,
      provider_id: @provider_id,
      content: "Child was engaged and participated well today",
      status: :pending_approval,
      rejection_reason: nil,
      submitted_at: @submitted_at,
      reviewed_at: nil,
      inserted_at: @inserted_at,
      updated_at: @updated_at
    }

    struct!(BehavioralNoteSchema, Map.merge(defaults, overrides))
  end

  defp valid_domain(overrides \\ %{}) do
    defaults = %{
      id: @note_id,
      participation_record_id: @record_id,
      child_id: @child_id,
      parent_id: @parent_id,
      provider_id: @provider_id,
      content: "Child was engaged and participated well today",
      status: :pending_approval,
      rejection_reason: nil,
      submitted_at: @submitted_at,
      reviewed_at: nil,
      inserted_at: @inserted_at,
      updated_at: @updated_at
    }

    struct!(BehavioralNote, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "maps all fields from schema to domain model" do
      schema = valid_schema()

      note = BehavioralNoteMapper.to_domain(schema)

      assert %BehavioralNote{} = note
      assert note.id == @note_id
      assert note.participation_record_id == @record_id
      assert note.child_id == @child_id
      assert note.parent_id == @parent_id
      assert note.provider_id == @provider_id
      assert note.content == "Child was engaged and participated well today"
      assert note.status == :pending_approval
      assert note.rejection_reason == nil
      assert note.submitted_at == @submitted_at
      assert note.reviewed_at == nil
      assert note.inserted_at == @inserted_at
      assert note.updated_at == @updated_at
    end

    test "maps :approved status with reviewed_at" do
      schema = valid_schema(%{status: :approved, reviewed_at: @reviewed_at})

      note = BehavioralNoteMapper.to_domain(schema)

      assert note.status == :approved
      assert note.reviewed_at == @reviewed_at
    end

    test "maps :rejected status with rejection_reason and reviewed_at" do
      schema =
        valid_schema(%{
          status: :rejected,
          rejection_reason: "Tone was inappropriate",
          reviewed_at: @reviewed_at
        })

      note = BehavioralNoteMapper.to_domain(schema)

      assert note.status == :rejected
      assert note.rejection_reason == "Tone was inappropriate"
      assert note.reviewed_at == @reviewed_at
    end

    test "preserves nil parent_id for notes without a linked parent" do
      schema = valid_schema(%{parent_id: nil})

      note = BehavioralNoteMapper.to_domain(schema)

      assert note.parent_id == nil
    end

    test "preserves nil rejection_reason for non-rejected notes" do
      schema = valid_schema(%{status: :pending_approval, rejection_reason: nil})

      note = BehavioralNoteMapper.to_domain(schema)

      assert note.rejection_reason == nil
    end
  end

  describe "to_persistence/1" do
    test "maps all domain fields to persistence map" do
      note = valid_domain()

      attrs = BehavioralNoteMapper.to_persistence(note)

      assert attrs.id == @note_id
      assert attrs.participation_record_id == @record_id
      assert attrs.child_id == @child_id
      assert attrs.parent_id == @parent_id
      assert attrs.provider_id == @provider_id
      assert attrs.content == "Child was engaged and participated well today"
      assert attrs.status == :pending_approval
      assert attrs.rejection_reason == nil
      assert attrs.submitted_at == @submitted_at
      assert attrs.reviewed_at == nil
    end

    test "excludes inserted_at and updated_at (managed by Ecto timestamps)" do
      note = valid_domain()

      attrs = BehavioralNoteMapper.to_persistence(note)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end

    test "includes nil optional fields (parent_id, rejection_reason, reviewed_at)" do
      note = valid_domain(%{parent_id: nil, rejection_reason: nil, reviewed_at: nil})

      attrs = BehavioralNoteMapper.to_persistence(note)

      assert Map.has_key?(attrs, :parent_id)
      assert Map.has_key?(attrs, :rejection_reason)
      assert Map.has_key?(attrs, :reviewed_at)
      assert attrs.parent_id == nil
      assert attrs.rejection_reason == nil
      assert attrs.reviewed_at == nil
    end

    test "maps :approved status with reviewed_at" do
      note = valid_domain(%{status: :approved, reviewed_at: @reviewed_at})

      attrs = BehavioralNoteMapper.to_persistence(note)

      assert attrs.status == :approved
      assert attrs.reviewed_at == @reviewed_at
    end

    test "maps :rejected status with rejection_reason" do
      note =
        valid_domain(%{
          status: :rejected,
          rejection_reason: "Needs revision",
          reviewed_at: @reviewed_at
        })

      attrs = BehavioralNoteMapper.to_persistence(note)

      assert attrs.status == :rejected
      assert attrs.rejection_reason == "Needs revision"
    end
  end

  describe "update_schema/1" do
    test "returns mutable field subset from domain model" do
      note = valid_domain()

      attrs = BehavioralNoteMapper.update_schema(%BehavioralNoteSchema{}, note)

      assert attrs.content == "Child was engaged and participated well today"
      assert attrs.status == :pending_approval
      assert attrs.rejection_reason == nil
      assert attrs.submitted_at == @submitted_at
      assert attrs.reviewed_at == nil
    end

    test "excludes immutable identity fields from update attrs" do
      note = valid_domain()

      attrs = BehavioralNoteMapper.update_schema(%BehavioralNoteSchema{}, note)

      refute Map.has_key?(attrs, :id)
      refute Map.has_key?(attrs, :participation_record_id)
      refute Map.has_key?(attrs, :child_id)
      refute Map.has_key?(attrs, :parent_id)
      refute Map.has_key?(attrs, :provider_id)
      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end

    test "reflects rejection data in update attrs" do
      note =
        valid_domain(%{
          status: :rejected,
          rejection_reason: "Too negative",
          reviewed_at: @reviewed_at
        })

      attrs = BehavioralNoteMapper.update_schema(%BehavioralNoteSchema{}, note)

      assert attrs.status == :rejected
      assert attrs.rejection_reason == "Too negative"
      assert attrs.reviewed_at == @reviewed_at
    end

    test "reflects approval data in update attrs" do
      note = valid_domain(%{status: :approved, reviewed_at: @reviewed_at})

      attrs = BehavioralNoteMapper.update_schema(%BehavioralNoteSchema{}, note)

      assert attrs.status == :approved
      assert attrs.reviewed_at == @reviewed_at
    end
  end
end
