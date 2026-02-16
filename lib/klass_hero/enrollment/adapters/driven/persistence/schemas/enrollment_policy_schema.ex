defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema do
  @moduledoc """
  Ecto schema for the enrollment_policies table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use EnrollmentPolicyMapper to convert between EnrollmentPolicySchema and
  domain EnrollmentPolicy entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "enrollment_policies" do
    field :program_id, :binary_id
    field :min_enrollment, :integer
    field :max_enrollment, :integer

    timestamps()
  end

  @required_fields ~w(program_id)a
  @optional_fields ~w(min_enrollment max_enrollment)a

  @doc """
  Creates a changeset for enrollment policy creation or update.

  Required fields:
  - program_id (valid UUID referencing a program)

  Optional fields:
  - min_enrollment (positive integer, minimum headcount to run)
  - max_enrollment (positive integer, hard enrollment cap)

  Database constraints enforce:
  - min_enrollment >= 1 when set
  - max_enrollment >= 1 when set
  - min_enrollment <= max_enrollment when both are set
  - One policy per program (unique on program_id)
  """
  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:min_enrollment, greater_than_or_equal_to: 1)
    |> validate_number(:max_enrollment, greater_than_or_equal_to: 1)
    |> validate_min_not_exceeds_max()
    |> unique_constraint(:program_id)
    |> check_constraint(:min_enrollment, name: :min_enrollment_positive)
    |> check_constraint(:max_enrollment, name: :max_enrollment_positive)
    |> check_constraint(:min_enrollment, name: :min_not_exceeds_max)
  end

  # Trigger: min_enrollment exceeds max_enrollment when both are set
  # Why: nonsensical policy — program could never run and accept enrollments simultaneously
  # Outcome: changeset error added before hitting the database constraint
  defp validate_min_not_exceeds_max(changeset) do
    min = get_field(changeset, :min_enrollment)
    max = get_field(changeset, :max_enrollment)

    if is_integer(min) and is_integer(max) and min > max do
      add_error(changeset, :min_enrollment, "must not exceed maximum enrollment")
    else
      changeset
    end
  end
end
