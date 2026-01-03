defmodule KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema do
  @moduledoc """
  Ecto schema for participation records.

  This is an infrastructure concern - it maps the domain model to the database.
  The schema should never be exposed outside the persistence adapter.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "participation_records" do
    field :child_id, :binary_id
    field :parent_id, :binary_id
    field :provider_id, :binary_id
    field :status, Ecto.Enum, values: [:registered, :checked_in, :checked_out, :absent]
    field :check_in_at, :utc_datetime
    field :check_in_notes, :string
    field :check_in_by, :binary_id
    field :check_out_at, :utc_datetime
    field :check_out_notes, :string
    field :check_out_by, :binary_id
    field :lock_version, :integer, default: 1

    belongs_to :session, ProgramSessionSchema

    timestamps(type: :utc_datetime)
  end

  @required_fields [:session_id, :child_id, :status]
  @optional_fields [
    :parent_id,
    :provider_id,
    :check_in_at,
    :check_in_notes,
    :check_in_by,
    :check_out_at,
    :check_out_notes,
    :check_out_by,
    :lock_version
  ]

  @doc "Creates a changeset for inserting a new participation record."
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, [:registered, :checked_in, :checked_out, :absent])
    |> unique_constraint([:session_id, :child_id],
      name: :participation_records_session_id_child_id_index,
      message: "child already registered for this session"
    )
    |> foreign_key_constraint(:session_id)
    |> optimistic_lock(:lock_version)
  end

  @doc "Creates a changeset for updating an existing participation record."
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, @optional_fields ++ [:status])
    |> validate_inclusion(:status, [:registered, :checked_in, :checked_out, :absent])
    |> optimistic_lock(:lock_version)
  end
end
