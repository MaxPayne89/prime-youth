defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Location do
  @moduledoc """
  Ecto schema for Location entity persistence.

  This is the infrastructure adapter that maps the Location domain entity to database tables.
  Supports both physical venues (with address) and virtual locations (with meeting links).

  ## Associations

  - `belongs_to :program` - Associated program (Program)

  ## Business Rules

  - Physical locations require: address_line1, city, state
  - Virtual locations require: virtual_link
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "locations" do
    field :name, :string
    field :address_line1, :string
    field :address_line2, :string
    field :city, :string
    field :state, :string
    field :postal_code, :string
    field :country, :string
    field :is_virtual, :boolean, default: false
    field :virtual_link, :string
    field :accessibility_notes, :string

    belongs_to :program, Program

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a location.

  Validates required fields based on location type (physical vs virtual).

  ## Required Fields

  - name, program_id (program_id optional when used with cast_assoc)
  - is_virtual (defaults to false)

  ## Conditional Requirements

  **Physical locations** (is_virtual = false):
  - address_line1, city, state

  **Virtual locations** (is_virtual = true):
  - virtual_link

  ## Optional Fields

  - address_line2, postal_code, country
  - accessibility_notes

  ## Validations

  - name: 2-200 characters
  - address fields: max 200 characters
  - city, state: max 100 characters
  - postal_code: max 20 characters
  - country: max 100 characters
  - accessibility_notes: max 500 characters
  - virtual_link: must be valid URL format
  """
  def changeset(location, attrs) do
    location
    |> cast(attrs, [
      :name,
      :address_line1,
      :address_line2,
      :city,
      :state,
      :postal_code,
      :country,
      :is_virtual,
      :virtual_link,
      :accessibility_notes,
      :program_id
    ])
    |> validate_required([:name])
    |> validate_required_program_id()
    |> validate_length(:name, min: 2, max: 200)
    |> validate_length(:address_line1, max: 200)
    |> validate_length(:address_line2, max: 200)
    |> validate_length(:city, max: 100)
    |> validate_length(:state, max: 100)
    |> validate_length(:postal_code, max: 20)
    |> validate_length(:country, max: 100)
    |> validate_length(:accessibility_notes, max: 500)
    |> validate_location_type_requirements()
    |> foreign_key_constraint(:program_id)
  end

  # Private validation helpers

  defp validate_required_program_id(changeset) do
    # Always validate program_id as required
    # When using cast_assoc from Program, the program_id should be included in nested params
    validate_required(changeset, [:program_id])
  end

  defp validate_location_type_requirements(changeset) do
    is_virtual = get_field(changeset, :is_virtual, false)

    if is_virtual do
      validate_virtual_location(changeset)
    else
      validate_physical_location(changeset)
    end
  end

  defp validate_virtual_location(changeset) do
    changeset
    |> validate_required([:virtual_link])
    |> validate_url_format(:virtual_link)
  end

  defp validate_physical_location(changeset) do
    changeset
    |> validate_required([:address_line1, :city, :state])
  end

  defp validate_url_format(changeset, field) do
    value = get_field(changeset, field)

    if value && not String.match?(value, ~r/^https?:\/\//) do
      add_error(changeset, field, "must be a valid URL starting with http:// or https://")
    else
      changeset
    end
  end
end
