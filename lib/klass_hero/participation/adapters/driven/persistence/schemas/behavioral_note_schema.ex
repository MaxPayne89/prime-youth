defmodule KlassHero.Participation.Adapters.Driven.Persistence.Schemas.BehavioralNoteSchema do
  @moduledoc """
  Ecto schema for behavioral notes.

  This is an infrastructure concern - it maps the domain model to the database.
  The schema should never be exposed outside the persistence adapter.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ParticipationRecordSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "behavioral_notes" do
    field :child_id, :binary_id
    field :parent_id, :binary_id
    field :provider_id, :binary_id
    field :content, :string
    field :status, Ecto.Enum, values: [:pending_approval, :approved, :rejected]
    field :rejection_reason, :string
    field :submitted_at, :utc_datetime
    field :reviewed_at, :utc_datetime

    belongs_to :participation_record, ParticipationRecordSchema

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :participation_record_id,
    :child_id,
    :provider_id,
    :content,
    :status,
    :submitted_at
  ]
  @optional_fields [:parent_id, :rejection_reason, :reviewed_at]

  @doc "Creates a changeset for inserting a new behavioral note."
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, [:pending_approval, :approved, :rejected])
    |> validate_length(:content, max: 1000)
    |> unique_constraint([:participation_record_id, :provider_id],
      name: :behavioral_notes_participation_record_id_provider_id_index,
      message: "note already exists for this provider and record"
    )
    |> foreign_key_constraint(:participation_record_id)
    |> foreign_key_constraint(:child_id)
  end

  @doc "Creates a changeset for updating an existing behavioral note."
  def update_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:content, :status, :rejection_reason, :submitted_at, :reviewed_at])
    |> validate_inclusion(:status, [:pending_approval, :approved, :rejected])
    |> validate_length(:content, max: 1000)
  end
end
