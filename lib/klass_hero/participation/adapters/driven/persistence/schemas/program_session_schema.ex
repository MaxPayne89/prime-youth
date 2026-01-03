defmodule KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema do
  @moduledoc """
  Ecto schema for program sessions.

  This is an infrastructure concern - it maps the domain model to the database.
  The schema should never be exposed outside the persistence adapter.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "program_sessions" do
    field :program_id, :binary_id
    field :session_date, :date
    field :start_time, :time
    field :end_time, :time
    field :status, Ecto.Enum, values: [:scheduled, :in_progress, :completed, :cancelled]
    field :location, :string
    field :notes, :string
    field :max_capacity, :integer
    field :lock_version, :integer, default: 1

    has_many :participation_records, ParticipationRecordSchema, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:program_id, :session_date, :start_time, :end_time, :status]
  @optional_fields [:location, :notes, :max_capacity, :lock_version]

  @doc "Creates a changeset for inserting a new session."
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, [:scheduled, :in_progress, :completed, :cancelled])
    |> validate_number(:max_capacity, greater_than: 0)
    |> validate_time_range()
    |> unique_constraint([:program_id, :session_date, :start_time],
      name: :program_sessions_program_id_session_date_start_time_index,
      message: "session already exists at this time"
    )
    |> optimistic_lock(:lock_version)
  end

  @doc "Creates a changeset for updating an existing session."
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, @optional_fields ++ [:status])
    |> validate_inclusion(:status, [:scheduled, :in_progress, :completed, :cancelled])
    |> validate_number(:max_capacity, greater_than: 0)
    |> optimistic_lock(:lock_version)
  end

  defp validate_time_range(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
