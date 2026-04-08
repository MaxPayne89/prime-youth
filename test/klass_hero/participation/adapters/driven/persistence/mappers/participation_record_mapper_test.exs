defmodule KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ParticipationRecordMapperTest do
  @moduledoc """
  Unit tests for ParticipationRecordMapper.

  Tests schema-to-domain and domain-to-persistence mappings.
  No database required — schemas and domain structs are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ParticipationRecordMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema
  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @record_id Ecto.UUID.generate()
  @session_id Ecto.UUID.generate()
  @child_id Ecto.UUID.generate()
  @parent_id Ecto.UUID.generate()
  @provider_id Ecto.UUID.generate()
  @staff_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: @record_id,
      session_id: @session_id,
      child_id: @child_id,
      parent_id: @parent_id,
      provider_id: @provider_id,
      status: :registered,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      lock_version: 1,
      inserted_at: ~U[2025-07-01 08:00:00Z],
      updated_at: ~U[2025-07-01 08:00:00Z]
    }

    struct!(ParticipationRecordSchema, Map.merge(defaults, overrides))
  end

  defp valid_record(overrides \\ %{}) do
    defaults = %{
      id: @record_id,
      session_id: @session_id,
      child_id: @child_id,
      parent_id: @parent_id,
      provider_id: @provider_id,
      status: :registered,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      lock_version: 1
    }

    struct!(ParticipationRecord, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "maps all fields from schema to domain struct" do
      schema = valid_schema()

      record = ParticipationRecordMapper.to_domain(schema)

      assert %ParticipationRecord{} = record
      assert record.id == @record_id
      assert record.session_id == @session_id
      assert record.child_id == @child_id
      assert record.parent_id == @parent_id
      assert record.provider_id == @provider_id
      assert record.status == :registered
      assert record.lock_version == 1
    end

    test "maps checked_in status with check-in timestamps and notes" do
      check_in_at = ~U[2025-07-01 09:05:00Z]

      schema =
        valid_schema(%{
          status: :checked_in,
          check_in_at: check_in_at,
          check_in_notes: "Arrived on time",
          check_in_by: @staff_id
        })

      record = ParticipationRecordMapper.to_domain(schema)

      assert record.status == :checked_in
      assert record.check_in_at == check_in_at
      assert record.check_in_notes == "Arrived on time"
      assert record.check_in_by == @staff_id
    end

    test "maps checked_out status with check-out timestamps" do
      check_in_at = ~U[2025-07-01 09:05:00Z]
      check_out_at = ~U[2025-07-01 12:00:00Z]

      schema =
        valid_schema(%{
          status: :checked_out,
          check_in_at: check_in_at,
          check_out_at: check_out_at,
          check_out_notes: "Early pick-up",
          check_out_by: @staff_id
        })

      record = ParticipationRecordMapper.to_domain(schema)

      assert record.status == :checked_out
      assert record.check_out_at == check_out_at
      assert record.check_out_notes == "Early pick-up"
      assert record.check_out_by == @staff_id
    end

    test "preserves nil optional fields" do
      schema = valid_schema(%{parent_id: nil, provider_id: nil})

      record = ParticipationRecordMapper.to_domain(schema)

      assert record.parent_id == nil
      assert record.provider_id == nil
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      record = ParticipationRecordMapper.to_domain(schema)

      assert record.inserted_at == ~U[2025-07-01 08:00:00Z]
      assert record.updated_at == ~U[2025-07-01 08:00:00Z]
    end
  end

  describe "to_persistence/1" do
    test "includes all required and optional fields" do
      record = valid_record()

      attrs = ParticipationRecordMapper.to_persistence(record)

      assert attrs.id == @record_id
      assert attrs.session_id == @session_id
      assert attrs.child_id == @child_id
      assert attrs.parent_id == @parent_id
      assert attrs.provider_id == @provider_id
      assert attrs.status == :registered
      assert attrs.lock_version == 1
    end

    test "includes nil optional fields (does not filter nils)" do
      record = valid_record(%{check_in_at: nil, check_in_notes: nil, check_in_by: nil})

      attrs = ParticipationRecordMapper.to_persistence(record)

      assert Map.has_key?(attrs, :check_in_at)
      assert attrs.check_in_at == nil
      assert Map.has_key?(attrs, :check_in_notes)
      assert attrs.check_in_notes == nil
    end

    test "does not include timestamps" do
      record = valid_record()

      attrs = ParticipationRecordMapper.to_persistence(record)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end
  end

  describe "update_schema/1" do
    test "returns a map with mutable check-in/check-out fields" do
      schema = valid_schema()
      check_in_at = ~U[2025-07-01 09:10:00Z]

      record =
        valid_record(%{
          status: :checked_in,
          check_in_at: check_in_at,
          check_in_notes: "On time",
          check_in_by: @staff_id,
          lock_version: 2
        })

      attrs = ParticipationRecordMapper.update_schema(schema, record)

      assert attrs == %{
               status: :checked_in,
               check_in_at: check_in_at,
               check_in_notes: "On time",
               check_in_by: @staff_id,
               check_out_at: nil,
               check_out_notes: nil,
               check_out_by: nil,
               lock_version: 2
             }
    end

    test "does not include immutable fields (id, session_id, child_id, parent_id, provider_id)" do
      schema = valid_schema()
      record = valid_record()

      attrs = ParticipationRecordMapper.update_schema(schema, record)

      refute Map.has_key?(attrs, :id)
      refute Map.has_key?(attrs, :session_id)
      refute Map.has_key?(attrs, :child_id)
      refute Map.has_key?(attrs, :parent_id)
      refute Map.has_key?(attrs, :provider_id)
    end
  end
end
