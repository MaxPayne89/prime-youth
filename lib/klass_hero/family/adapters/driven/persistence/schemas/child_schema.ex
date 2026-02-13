defmodule KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema do
  @moduledoc """
  Ecto schema for the children table.

  Maps the children database table to an Elixir struct with comprehensive
  validation. Use ChildMapper for domain entity conversion.

  ## Fields

  - `id` - Binary UUID primary key
  - `parent_id` - Foreign key to parents table
  - `first_name` - Child's first name (1-100 characters)
  - `last_name` - Child's last name (1-100 characters)
  - `date_of_birth` - Child's birth date (must be in the past)
  - `emergency_contact` - Optional emergency contact info (max 255 characters)
  - `support_needs` - Optional support needs or accommodations
  - `allergies` - Optional allergy information
  - `inserted_at` - Timestamp when record was created
  - `updated_at` - Timestamp when record was last updated
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "children" do
    field :parent_id, :binary_id
    field :first_name, :string
    field :last_name, :string
    field :date_of_birth, :date
    field :emergency_contact, :string
    field :support_needs, :string
    field :allergies, :string

    timestamps()
  end

  @doc """
  Changeset for anonymizing a child record during GDPR account deletion.

  Receives pre-defined anonymized values from the domain model and applies
  them mechanically. Preserves `parent_id` for referential integrity with
  participation records.
  """
  def anonymize_changeset(%__MODULE__{} = child, anonymized_attrs)
      when is_map(anonymized_attrs) do
    change(child, anonymized_attrs)
  end

  @doc """
  Changeset for creating or updating a child record.

  ## Validations

  - Required: parent_id, first_name, last_name, date_of_birth
  - first_name and last_name: 1-100 characters
  - date_of_birth: must be in the past (before today)
  - Foreign key constraint on parent_id
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :parent_id,
      :first_name,
      :last_name,
      :date_of_birth,
      :emergency_contact,
      :support_needs,
      :allergies
    ])
    |> validate_required([:parent_id, :first_name, :last_name, :date_of_birth])
    |> shared_validations()
    |> foreign_key_constraint(:parent_id)
  end

  @doc """
  Form changeset for LiveView forms.

  Excludes `parent_id` from cast and validate_required since it is set
  programmatically by the use case layer, not via user input.
  """
  def form_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :first_name,
      :last_name,
      :date_of_birth,
      :emergency_contact,
      :support_needs,
      :allergies
    ])
    |> validate_required([:first_name, :last_name, :date_of_birth])
    |> shared_validations()
  end

  defp shared_validations(changeset) do
    changeset
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:emergency_contact, max: 255)
    |> validate_date_in_past(:date_of_birth)
  end

  defp validate_date_in_past(changeset, field) do
    validate_change(changeset, field, fn ^field, date ->
      today = Date.utc_today()

      case Date.compare(date, today) do
        :lt -> []
        _ -> [{field, "must be in the past"}]
      end
    end)
  end
end
