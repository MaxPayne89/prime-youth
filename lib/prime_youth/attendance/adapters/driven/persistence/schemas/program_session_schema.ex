defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema do
  @moduledoc """
  Ecto schema for the program_sessions table.

  Use ProgramSessionMapper for domain entity conversion.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "program_sessions" do
    field :program_id, :binary_id
    field :session_date, :date
    field :start_time, :time
    field :end_time, :time
    field :max_capacity, :integer
    field :status, :string
    field :notes, :string

    timestamps()
  end

  def changeset(program_session_schema, attrs) do
    program_session_schema
    |> cast(attrs, [
      :program_id,
      :session_date,
      :start_time,
      :end_time,
      :max_capacity,
      :status,
      :notes
    ])
    |> validate_required([
      :program_id,
      :session_date,
      :start_time,
      :end_time,
      :max_capacity,
      :status
    ])
    |> validate_number(:max_capacity, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["scheduled", "in_progress", "completed", "cancelled"])
    |> unique_constraint([:program_id, :session_date, :start_time],
      name: :program_sessions_program_id_session_date_start_time_index,
      message: "session already exists at this date and time"
    )
    |> check_constraint(:max_capacity,
      name: :max_capacity_must_be_non_negative,
      message: "must be >= 0"
    )
    |> check_constraint(:end_time,
      name: :end_time_after_start_time,
      message: "must be after start time"
    )
  end
end
