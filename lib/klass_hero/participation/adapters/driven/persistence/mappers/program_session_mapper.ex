defmodule KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper do
  @moduledoc """
  Maps between ProgramSession domain model and ProgramSessionSchema.

  This mapper ensures clean separation between the domain layer and persistence layer.
  """

  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.Participation.Domain.Models.ProgramSession

  @doc "Converts a ProgramSessionSchema to a ProgramSession domain model."
  @spec to_domain(ProgramSessionSchema.t()) :: ProgramSession.t()
  def to_domain(%ProgramSessionSchema{} = schema) do
    %ProgramSession{
      id: schema.id,
      program_id: schema.program_id,
      session_date: schema.session_date,
      start_time: schema.start_time,
      end_time: schema.end_time,
      status: schema.status,
      location: schema.location,
      notes: schema.notes,
      max_capacity: schema.max_capacity,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at,
      lock_version: schema.lock_version
    }
  end

  @doc "Converts a ProgramSession domain model to attributes for persistence."
  @spec to_persistence(ProgramSession.t()) :: map()
  def to_persistence(%ProgramSession{} = session) do
    %{
      id: session.id,
      program_id: session.program_id,
      session_date: session.session_date,
      start_time: session.start_time,
      end_time: session.end_time,
      status: session.status,
      location: session.location,
      notes: session.notes,
      max_capacity: session.max_capacity,
      lock_version: session.lock_version
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc "Updates a schema struct with domain model values for update operations."
  @spec update_schema(ProgramSessionSchema.t(), ProgramSession.t()) :: map()
  def update_schema(%ProgramSessionSchema{}, %ProgramSession{} = session) do
    %{
      status: session.status,
      location: session.location,
      notes: session.notes,
      max_capacity: session.max_capacity,
      lock_version: session.lock_version
    }
  end
end
