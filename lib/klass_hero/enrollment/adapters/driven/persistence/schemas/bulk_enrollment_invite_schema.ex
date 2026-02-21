defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema do
  @moduledoc """
  Ecto schema for the bulk_enrollment_invites table.

  Stores denormalized CSV data as a staging record for bulk enrollment.
  When a parent acts on the invite, real domain entities (User, ParentProfile,
  Child, Enrollment, Consents) are created from this data.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(pending invite_sent registered enrolled failed)

  schema "bulk_enrollment_invites" do
    field :program_id, :binary_id
    field :provider_id, :binary_id
    field :child_first_name, :string
    field :child_last_name, :string
    field :child_date_of_birth, :date
    field :guardian_email, :string
    field :guardian_first_name, :string
    field :guardian_last_name, :string
    field :guardian2_email, :string
    field :guardian2_first_name, :string
    field :guardian2_last_name, :string
    field :school_grade, :integer
    field :school_name, :string
    field :medical_conditions, :string
    field :nut_allergy, :boolean, default: false
    field :consent_photo_marketing, :boolean, default: false
    field :consent_photo_social_media, :boolean, default: false
    field :status, :string, default: "pending"
    field :invite_token, :string
    field :invite_sent_at, :utc_datetime
    field :registered_at, :utc_datetime
    field :enrolled_at, :utc_datetime
    field :enrollment_id, :binary_id
    field :error_details, :string

    timestamps()
  end

  @required_fields ~w(program_id provider_id child_first_name child_last_name child_date_of_birth guardian_email)a

  @optional_fields ~w(
    guardian_first_name guardian_last_name
    guardian2_email guardian2_first_name guardian2_last_name
    school_grade school_name medical_conditions nut_allergy
    consent_photo_marketing consent_photo_social_media
    status invite_token invite_sent_at registered_at enrolled_at
    enrollment_id error_details
  )a

  @import_fields ~w(
    program_id provider_id child_first_name child_last_name child_date_of_birth
    guardian_email guardian_first_name guardian_last_name
    guardian2_email guardian2_first_name guardian2_last_name
    school_grade school_name medical_conditions nut_allergy
    consent_photo_marketing consent_photo_social_media
  )a

  @valid_transitions %{
    "pending" => ["invite_sent", "failed"],
    "invite_sent" => ["registered", "failed"],
    "registered" => ["enrolled", "failed"],
    "enrolled" => [],
    "failed" => ["pending"]
  }

  @lifecycle_fields ~w(
    status invite_token invite_sent_at registered_at enrolled_at
    enrollment_id error_details
  )a

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:child_first_name, min: 1, max: 100)
    |> validate_length(:child_last_name, min: 1, max: 100)
    |> validate_length(:guardian_email, max: 160)
    |> validate_format(:guardian_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email"
    )
    |> validate_length(:guardian_first_name, max: 100)
    |> validate_length(:guardian_last_name, max: 100)
    |> validate_length(:guardian2_email, max: 160)
    |> maybe_validate_guardian2_email()
    |> validate_length(:guardian2_first_name, max: 100)
    |> validate_length(:guardian2_last_name, max: 100)
    |> validate_length(:school_name, max: 255)
    |> validate_number(:school_grade, greater_than_or_equal_to: 1, less_than_or_equal_to: 13)
    |> validate_date_in_past(:child_date_of_birth)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:program_id, :guardian_email, :child_first_name, :child_last_name],
      name: :bulk_invites_program_guardian_child_unique
    )
    |> unique_constraint(:invite_token)
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:enrollment_id)
    |> check_constraint(:status, name: :valid_status)
    |> check_constraint(:school_grade, name: :valid_school_grade)
  end

  def valid_statuses, do: @valid_statuses

  @doc "Returns the valid status transitions map."
  def valid_transitions, do: @valid_transitions

  @doc """
  Changeset for creating invite records from CSV import data.

  Only accepts fields from the CSV. Status defaults to "pending".
  Lifecycle fields (invite_token, timestamps, enrollment_id, error_details)
  are managed via transition_changeset/2.
  """
  def import_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @import_fields)
    |> validate_required(@required_fields)
    |> validate_length(:child_first_name, min: 1, max: 100)
    |> validate_length(:child_last_name, min: 1, max: 100)
    |> validate_length(:guardian_email, max: 160)
    |> validate_format(:guardian_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email"
    )
    |> validate_length(:guardian_first_name, max: 100)
    |> validate_length(:guardian_last_name, max: 100)
    |> validate_length(:guardian2_email, max: 160)
    |> maybe_validate_guardian2_email()
    |> validate_length(:guardian2_first_name, max: 100)
    |> validate_length(:guardian2_last_name, max: 100)
    |> validate_length(:school_name, max: 255)
    |> validate_number(:school_grade, greater_than_or_equal_to: 1, less_than_or_equal_to: 13)
    |> validate_date_in_past(:child_date_of_birth)
    |> unique_constraint([:program_id, :guardian_email, :child_first_name, :child_last_name],
      name: :bulk_invites_program_guardian_child_unique
    )
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:provider_id)
    |> check_constraint(:school_grade, name: :valid_school_grade)
  end

  @doc """
  Changeset for transitioning invite status.

  Validates that the transition from current status to target status
  is legal per the state machine. Also casts lifecycle fields.
  """
  def transition_changeset(%__MODULE__{} = schema, attrs) do
    schema
    |> cast(attrs, @lifecycle_fields)
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_status_transition()
    |> unique_constraint(:invite_token)
    |> foreign_key_constraint(:enrollment_id)
    |> check_constraint(:status, name: :valid_status)
  end

  # Trigger: guardian2_email is present and non-nil
  # Why: if a second guardian email is provided, it must be valid
  # Outcome: format validation applied only when field has a value
  defp maybe_validate_guardian2_email(changeset) do
    case get_field(changeset, :guardian2_email) do
      nil ->
        changeset

      "" ->
        changeset

      _email ->
        validate_format(changeset, :guardian2_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
          message: "must be a valid email"
        )
    end
  end

  defp validate_date_in_past(changeset, field) do
    validate_change(changeset, field, fn ^field, date ->
      if Date.before?(date, Date.utc_today()) do
        []
      else
        [{field, "must be in the past"}]
      end
    end)
  end

  # Trigger: status is being changed
  # Why: invites follow a strict lifecycle (pending -> invite_sent -> registered -> enrolled)
  # Outcome: invalid transitions are rejected with a clear error message
  defp validate_status_transition(changeset) do
    case {changeset.data.status, get_change(changeset, :status)} do
      {_current, nil} ->
        changeset

      {current, target} ->
        allowed = Map.get(@valid_transitions, current, [])

        if target in allowed do
          changeset
        else
          add_error(changeset, :status, "cannot transition from #{current} to #{target}",
            validation: :status_transition,
            from: current,
            to: target
          )
        end
    end
  end
end
