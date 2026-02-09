defmodule KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema do
  @moduledoc """
  Ecto schema for the staff_members table.

  Use StaffMemberMapper to convert between this schema and domain StaffMember entities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "staff_members" do
    field :provider_id, :binary_id
    field :first_name, :string
    field :last_name, :string
    field :role, :string
    field :email, :string
    field :bio, :string
    field :headshot_url, :string
    field :tags, {:array, :string}, default: []
    field :qualifications, {:array, :string}, default: []
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :provider_id,
      :first_name,
      :last_name,
      :role,
      :email,
      :bio,
      :headshot_url,
      :tags,
      :qualifications,
      :active
    ])
    |> validate_required([:provider_id, :first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:headshot_url, max: 500)
    |> validate_tags()
    |> foreign_key_constraint(:provider_id)
  end

  @doc """
  Form changeset for editing staff members via LiveView.
  Excludes provider_id (set programmatically, not editable).
  """
  def edit_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :first_name,
      :last_name,
      :role,
      :email,
      :bio,
      :tags,
      :qualifications,
      :active
    ])
    |> validate_required([:first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    case get_change(changeset, :tags) do
      nil ->
        changeset

      tags ->
        valid = ProgramCategories.program_categories()
        invalid = Enum.reject(tags, &(&1 in valid))

        if invalid == [] do
          changeset
        else
          add_error(changeset, :tags, "contains invalid tags: #{Enum.join(invalid, ", ")}")
        end
    end
  end
end
