defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper do
  @moduledoc """
  Bidirectional mapping between ProgramSession domain entities and ProgramSessionSchema.

  This adapter provides bidirectional conversion:
  - to_domain/1: ProgramSessionSchema → ProgramSession (for reading from database)
  - to_schema/1: ProgramSession → ProgramSessionSchema attributes (for creating/updating)
  - to_domain_list/1: [ProgramSessionSchema] → [ProgramSession] (convenience for collections)

  ## Design Note: to_schema Excludes Database-Managed Fields

  The `to_schema/1` function intentionally excludes:
  - `id` - Managed by Ecto on insert
  - `inserted_at`, `updated_at` - Managed by Ecto timestamps

  This follows standard Ecto patterns where the database/framework manages
  these fields automatically. The repository handles id explicitly when needed.
  """

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  @valid_statuses ~w(scheduled in_progress completed cancelled)a

  def to_domain(%ProgramSessionSchema{} = schema) do
    %ProgramSession{
      id: to_string(schema.id),
      program_id: to_string(schema.program_id),
      session_date: schema.session_date,
      start_time: schema.start_time,
      end_time: schema.end_time,
      max_capacity: schema.max_capacity,
      status: parse_status(schema.status),
      notes: schema.notes,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp parse_status(status) when is_binary(status) do
    atom = String.to_atom(status)
    if atom in @valid_statuses, do: atom, else: :scheduled
  end

  defp parse_status(status) when is_atom(status), do: status

  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  @doc """
  Converts domain entity to update attributes.

  Excludes id and timestamps (managed by Ecto).
  UUIDs are passed as strings - Ecto's :binary_id handles the conversion.
  """
  def to_schema(%ProgramSession{} = session) do
    %{
      program_id: session.program_id,
      session_date: session.session_date,
      start_time: session.start_time,
      end_time: session.end_time,
      max_capacity: session.max_capacity,
      status: Atom.to_string(session.status),
      notes: session.notes
    }
  end
end
