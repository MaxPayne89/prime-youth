defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema do
  @moduledoc """
  Ecto schema for the enrollments table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use EnrollmentMapper to convert between EnrollmentSchema and domain Enrollment entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(pending confirmed completed cancelled)
  @valid_payment_methods ~w(card transfer)

  schema "enrollments" do
    field :program_id, :binary_id
    field :child_id, :binary_id
    field :parent_id, :binary_id
    field :status, :string
    field :enrolled_at, :utc_datetime
    field :confirmed_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string
    field :subtotal, :decimal
    field :vat_amount, :decimal
    field :card_fee_amount, :decimal
    field :total_amount, :decimal
    field :payment_method, :string
    field :special_requirements, :string

    timestamps()
  end

  @required_fields ~w(program_id child_id parent_id status enrolled_at)a
  @optional_fields ~w(
    confirmed_at completed_at cancelled_at cancellation_reason
    subtotal vat_amount card_fee_amount total_amount
    payment_method special_requirements
  )a

  @doc """
  Creates a changeset for new enrollment creation.

  Required fields:
  - program_id (valid UUID)
  - child_id (valid UUID)
  - parent_id (valid UUID)
  - status (pending, confirmed, completed, or cancelled)
  - enrolled_at (UTC datetime)

  Optional fields:
  - confirmed_at, completed_at, cancelled_at (UTC datetime)
  - cancellation_reason (text, max 1000 chars)
  - subtotal, vat_amount, card_fee_amount, total_amount (decimal)
  - payment_method (card or transfer)
  - special_requirements (text, max 500 chars)
  """
  def create_changeset(enrollment_schema \\ %__MODULE__{}, attrs) do
    enrollment_schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:payment_method, @valid_payment_methods ++ [nil])
    |> validate_length(:cancellation_reason, max: 1000)
    |> validate_length(:special_requirements, max: 500)
    |> validate_number(:subtotal, greater_than_or_equal_to: 0)
    |> validate_number(:vat_amount, greater_than_or_equal_to: 0)
    |> validate_number(:card_fee_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
    |> unique_constraint([:program_id, :child_id],
      name: :enrollments_program_child_active_index,
      message: "Active enrollment already exists for this child and program"
    )
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:child_id)
    |> foreign_key_constraint(:parent_id)
  end

  @doc """
  Creates a changeset for updating an existing enrollment.

  Does not allow modification of program_id, child_id, or parent_id.
  """
  def update_changeset(enrollment_schema, attrs) do
    enrollment_schema
    |> cast(attrs, @optional_fields ++ [:status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:payment_method, @valid_payment_methods ++ [nil])
    |> validate_length(:cancellation_reason, max: 1000)
    |> validate_length(:special_requirements, max: 500)
    |> validate_number(:subtotal, greater_than_or_equal_to: 0)
    |> validate_number(:vat_amount, greater_than_or_equal_to: 0)
    |> validate_number(:card_fee_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
  end
end
