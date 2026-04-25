defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema do
  @moduledoc """
  Ecto schema for the incident_reports table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use IncidentReportMapper to convert between IncidentReportSchema and domain
  IncidentReport entities.

  ## Field Name Mapping

  The database uses `provider_id` to reference the `providers` table.
  The domain model uses `provider_profile_id` for semantic clarity.
  The mapper handles this translation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "incident_reports" do
    field :provider_id, :binary_id
    field :reporter_user_id, :binary_id
    field :reporter_display_name, :string
    field :program_id, :binary_id
    field :session_id, :binary_id
    field :category, Ecto.Enum, values: IncidentReport.valid_categories()
    field :severity, Ecto.Enum, values: IncidentReport.valid_severities()
    field :description, :string
    field :occurred_at, :utc_datetime
    field :photo_url, :string
    field :original_filename, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :id,
    :provider_id,
    :reporter_user_id,
    :reporter_display_name,
    :category,
    :severity,
    :description,
    :occurred_at
  ]

  @optional_fields [:program_id, :session_id, :photo_url, :original_filename]

  @doc """
  Creates a changeset for inserting an incident report.

  Required fields:
  - id (client-provided UUID — domain owns identity)
  - provider_id (FK → providers)
  - reporter_user_id (FK → users)
  - category, severity (validated as Ecto.Enum)
  - description, occurred_at

  Optional fields:
  - program_id (FK → programs) OR session_id (FK → program_sessions); exactly
    one must be set. Enforced at the DB layer by the
    `one_of_program_or_session` check constraint.
  - photo_url, original_filename
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> check_constraint(:target,
      name: :one_of_program_or_session,
      message: "exactly one of program_id or session_id must be set"
    )
    |> check_constraint(:category, name: :category_check, message: "is invalid")
    |> check_constraint(:severity, name: :severity_check, message: "is invalid")
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:reporter_user_id)
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:session_id)
  end
end
