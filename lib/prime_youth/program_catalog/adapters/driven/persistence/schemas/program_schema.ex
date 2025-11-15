defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema do
  @moduledoc """
  Ecto schema for the programs table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use ProgramMapper to convert between ProgramSchema and domain Program entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "programs" do
    field :title, :string
    field :description, :string
    field :schedule, :string
    field :age_range, :string
    field :price, :decimal
    field :pricing_period, :string
    field :spots_available, :integer, default: 0
    field :gradient_class, :string
    field :icon_path, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          schedule: String.t() | nil,
          age_range: String.t() | nil,
          price: Decimal.t() | nil,
          pricing_period: String.t() | nil,
          spots_available: integer() | nil,
          gradient_class: String.t() | nil,
          icon_path: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a changeset for validation.

  Required fields:
  - title (1-255 characters)
  - description (non-empty)
  - schedule (non-empty)
  - age_range (non-empty)
  - price (>= 0)
  - pricing_period (non-empty)
  - spots_available (>= 0)

  Optional fields:
  - gradient_class
  - icon_path
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(program_schema, attrs) do
    program_schema
    |> cast(attrs, [
      :title,
      :description,
      :schedule,
      :age_range,
      :price,
      :pricing_period,
      :spots_available,
      :gradient_class,
      :icon_path
    ])
    |> validate_required([
      :title,
      :description,
      :schedule,
      :age_range,
      :price,
      :pricing_period,
      :spots_available
    ])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, min: 1, max: 500)
    |> validate_length(:schedule, min: 1, max: 255)
    |> validate_length(:age_range, min: 1, max: 100)
    |> validate_length(:pricing_period, min: 1, max: 100)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:spots_available, greater_than_or_equal_to: 0)
  end
end
