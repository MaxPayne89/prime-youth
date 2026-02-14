defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema do
  @moduledoc """
  Ecto schema for the programs table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use ProgramMapper to convert between ProgramSchema and domain Program entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "programs" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :schedule, :string
    field :age_range, :string
    field :price, :decimal
    field :pricing_period, :string
    field :spots_available, :integer, default: 0
    field :lock_version, :integer, default: 1
    field :icon_path, :string
    field :end_date, :utc_datetime
    field :provider_id, :binary_id
    field :location, :string
    field :cover_image_url, :string
    field :instructor_id, :binary_id
    field :instructor_name, :string
    field :instructor_headshot_url, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          category: String.t() | nil,
          schedule: String.t() | nil,
          age_range: String.t() | nil,
          price: Decimal.t() | nil,
          pricing_period: String.t() | nil,
          spots_available: integer() | nil,
          lock_version: integer() | nil,
          icon_path: String.t() | nil,
          end_date: DateTime.t() | nil,
          provider_id: Ecto.UUID.t() | nil,
          location: String.t() | nil,
          cover_image_url: String.t() | nil,
          instructor_id: Ecto.UUID.t() | nil,
          instructor_name: String.t() | nil,
          instructor_headshot_url: String.t() | nil,
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
  - icon_path
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(program_schema, attrs) do
    program_schema
    |> cast(attrs, [
      :title,
      :description,
      :category,
      :schedule,
      :age_range,
      :price,
      :pricing_period,
      :spots_available,
      :icon_path,
      :end_date,
      :provider_id,
      :location,
      :cover_image_url,
      :instructor_id,
      :instructor_name,
      :instructor_headshot_url
    ])
    |> validate_required([
      :title,
      :description,
      :category,
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
    |> validate_inclusion(:category, ProgramCategories.program_categories())
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:spots_available, greater_than_or_equal_to: 0)
  end

  @doc """
  Creates a changeset for program creation.

  Requires only the minimal fields needed to create a program.
  Schedule, age_range, and pricing_period are optional at creation time.
  """
  def create_changeset(program_schema, attrs) do
    program_schema
    |> cast(attrs, [
      :title,
      :description,
      :category,
      :price,
      :location,
      :spots_available
    ])
    # Trigger: provider_id, instructor fields arrive from trusted server-side code
    # Why: including them in cast would allow form param injection
    # Outcome: fields are set explicitly via put_change, not from user input
    |> maybe_put_change(:provider_id, attrs)
    |> maybe_put_change(:cover_image_url, attrs)
    |> maybe_put_change(:instructor_id, attrs)
    |> maybe_put_change(:instructor_name, attrs)
    |> maybe_put_change(:instructor_headshot_url, attrs)
    |> validate_required([:title, :description, :category, :price, :provider_id])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, min: 1, max: 500)
    |> validate_length(:location, max: 255)
    |> validate_length(:cover_image_url, max: 500)
    |> validate_length(:instructor_name, max: 200)
    |> validate_inclusion(:category, ProgramCategories.program_categories())
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:spots_available, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:instructor_id)
  end

  @doc """
  Creates an update changeset with optimistic locking.

  Applies the same validations as changeset/2 but adds optimistic locking
  to prevent concurrent update conflicts.

  Returns a changeset that will fail with Ecto.StaleEntryError if the
  record has been modified by another process since it was loaded.
  """
  def update_changeset(program_schema, attrs) do
    program_schema
    |> cast(attrs, [
      :title,
      :description,
      :category,
      :schedule,
      :age_range,
      :price,
      :pricing_period,
      :spots_available,
      :icon_path,
      :end_date,
      :location,
      :cover_image_url,
      :instructor_id,
      :instructor_name,
      :instructor_headshot_url
    ])
    |> validate_required([
      :title,
      :description,
      :category,
      :price,
      :spots_available
    ])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, min: 1, max: 500)
    |> validate_length(:schedule, max: 255)
    |> validate_length(:age_range, max: 100)
    |> validate_length(:pricing_period, max: 100)
    |> validate_inclusion(:category, ProgramCategories.program_categories())
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:spots_available, greater_than_or_equal_to: 0)
    |> optimistic_lock(:lock_version)
  end

  # Trigger: attrs may or may not contain the given key
  # Why: programmatic fields must bypass cast but still appear as changes
  # Outcome: put_change only when the key is present in the atom-keyed attrs map
  defp maybe_put_change(changeset, key, attrs) when is_atom(key) do
    if Map.has_key?(attrs, key) do
      put_change(changeset, key, Map.get(attrs, key))
    else
      changeset
    end
  end
end
