defmodule KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ProgramSessionMapperTest do
  @moduledoc """
  Unit tests for ProgramSessionMapper.

  Tests schema-to-domain and domain-to-persistence mappings.
  No database required — schemas and domain structs are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.Participation.Domain.Models.ProgramSession

  @session_id Ecto.UUID.generate()
  @program_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: @session_id,
      program_id: @program_id,
      session_date: ~D[2025-07-15],
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      status: :scheduled,
      location: "Main Hall",
      notes: "Bring sunscreen",
      max_capacity: 20,
      lock_version: 1,
      inserted_at: ~U[2025-06-01 10:00:00Z],
      updated_at: ~U[2025-06-01 10:00:00Z]
    }

    struct!(ProgramSessionSchema, Map.merge(defaults, overrides))
  end

  defp valid_session(overrides \\ %{}) do
    defaults = %{
      id: @session_id,
      program_id: @program_id,
      session_date: ~D[2025-07-15],
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      status: :scheduled,
      location: "Main Hall",
      notes: "Bring sunscreen",
      max_capacity: 20,
      lock_version: 1
    }

    struct!(ProgramSession, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "maps all required fields from schema to domain struct" do
      schema = valid_schema()

      session = ProgramSessionMapper.to_domain(schema)

      assert %ProgramSession{} = session
      assert session.id == @session_id
      assert session.program_id == @program_id
      assert session.session_date == ~D[2025-07-15]
      assert session.start_time == ~T[09:00:00]
      assert session.end_time == ~T[12:00:00]
      assert session.status == :scheduled
    end

    test "maps optional fields when present" do
      schema = valid_schema(%{location: "Room 2", notes: "Indoor session", max_capacity: 15})

      session = ProgramSessionMapper.to_domain(schema)

      assert session.location == "Room 2"
      assert session.notes == "Indoor session"
      assert session.max_capacity == 15
    end

    test "preserves nil optional fields" do
      schema = valid_schema(%{location: nil, notes: nil, max_capacity: nil})

      session = ProgramSessionMapper.to_domain(schema)

      assert session.location == nil
      assert session.notes == nil
      assert session.max_capacity == nil
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      session = ProgramSessionMapper.to_domain(schema)

      assert session.inserted_at == ~U[2025-06-01 10:00:00Z]
      assert session.updated_at == ~U[2025-06-01 10:00:00Z]
    end

    test "maps all valid status values" do
      for status <- ProgramSession.valid_statuses() do
        schema = valid_schema(%{status: status})

        session = ProgramSessionMapper.to_domain(schema)

        assert session.status == status
      end
    end
  end

  describe "to_persistence/1" do
    test "includes all non-nil fields" do
      session = valid_session()

      attrs = ProgramSessionMapper.to_persistence(session)

      assert attrs.id == @session_id
      assert attrs.program_id == @program_id
      assert attrs.session_date == ~D[2025-07-15]
      assert attrs.start_time == ~T[09:00:00]
      assert attrs.end_time == ~T[12:00:00]
      assert attrs.status == :scheduled
      assert attrs.location == "Main Hall"
      assert attrs.notes == "Bring sunscreen"
      assert attrs.max_capacity == 20
      assert attrs.lock_version == 1
    end

    test "excludes nil optional fields from the persistence map" do
      session = valid_session(%{location: nil, notes: nil, max_capacity: nil})

      attrs = ProgramSessionMapper.to_persistence(session)

      refute Map.has_key?(attrs, :location)
      refute Map.has_key?(attrs, :notes)
      refute Map.has_key?(attrs, :max_capacity)
    end

    test "excludes only nil fields while keeping non-nil optional fields" do
      session = valid_session(%{location: "Park", notes: nil, max_capacity: nil})

      attrs = ProgramSessionMapper.to_persistence(session)

      assert attrs.location == "Park"
      refute Map.has_key?(attrs, :notes)
      refute Map.has_key?(attrs, :max_capacity)
    end

    test "does not include timestamps" do
      session = valid_session()

      attrs = ProgramSessionMapper.to_persistence(session)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end
  end

  describe "update_schema/2" do
    test "returns a map with mutable fields only" do
      schema = valid_schema()

      session =
        valid_session(%{status: :in_progress, location: "Gym", notes: "Updated", max_capacity: 25, lock_version: 2})

      attrs = ProgramSessionMapper.update_schema(schema, session)

      assert attrs == %{
               status: :in_progress,
               location: "Gym",
               notes: "Updated",
               max_capacity: 25,
               lock_version: 2
             }
    end

    test "does not include immutable fields (id, program_id, session_date, start_time, end_time)" do
      schema = valid_schema()
      session = valid_session()

      attrs = ProgramSessionMapper.update_schema(schema, session)

      refute Map.has_key?(attrs, :id)
      refute Map.has_key?(attrs, :program_id)
      refute Map.has_key?(attrs, :session_date)
      refute Map.has_key?(attrs, :start_time)
      refute Map.has_key?(attrs, :end_time)
    end
  end
end
