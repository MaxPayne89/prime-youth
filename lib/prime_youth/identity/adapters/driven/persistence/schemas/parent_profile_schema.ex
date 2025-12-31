defmodule PrimeYouth.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema do
  @moduledoc """
  Ecto schema for the parents table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use ParentProfileMapper to convert between ParentProfileSchema and domain ParentProfile entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "parents" do
    field :identity_id, :binary_id
    field :display_name, :string
    field :phone, :string
    field :location, :string
    field :notification_preferences, :map

    timestamps()
  end

  @doc """
  Creates a changeset for validation.

  Required fields:
  - identity_id (must be a valid UUID)

  Optional fields:
  - display_name (1-100 characters if provided)
  - phone (1-20 characters if provided)
  - location (1-200 characters if provided)
  - notification_preferences (must be a map if provided)
  """
  def changeset(parent_profile_schema, attrs) do
    parent_profile_schema
    |> cast(attrs, [
      :identity_id,
      :display_name,
      :phone,
      :location,
      :notification_preferences
    ])
    |> validate_required([:identity_id])
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_length(:phone, min: 1, max: 20)
    |> validate_length(:location, min: 1, max: 200)
    |> unique_constraint(:identity_id,
      name: :parents_identity_id_index,
      message: "Parent profile already exists for this identity"
    )
  end
end
