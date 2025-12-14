defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema do
  @moduledoc """
  Ecto schema for the providers table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use ProviderMapper to convert between ProviderSchema and domain Provider entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "providers" do
    field :identity_id, :binary_id
    field :business_name, :string
    field :description, :string
    field :phone, :string
    field :website, :string
    field :address, :string
    field :logo_url, :string
    field :verified, :boolean, default: false
    field :verified_at, :utc_datetime
    field :categories, {:array, :string}, default: []

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          identity_id: Ecto.UUID.t() | nil,
          business_name: String.t() | nil,
          description: String.t() | nil,
          phone: String.t() | nil,
          website: String.t() | nil,
          address: String.t() | nil,
          logo_url: String.t() | nil,
          verified: boolean() | nil,
          verified_at: DateTime.t() | nil,
          categories: [String.t()] | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a changeset for validation.

  Required fields:
  - identity_id (must be a valid UUID)
  - business_name (1-200 characters)

  Optional fields:
  - description (1-1000 characters if provided)
  - phone (1-20 characters if provided)
  - website (1-500 characters if provided, must start with https://)
  - address (1-500 characters if provided)
  - logo_url (1-500 characters if provided)
  - verified (boolean, defaults to false)
  - verified_at (DateTime if provided)
  - categories (list of strings, defaults to [])
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(provider_schema, attrs) do
    provider_schema
    |> cast(attrs, [
      :identity_id,
      :business_name,
      :description,
      :phone,
      :website,
      :address,
      :logo_url,
      :verified,
      :verified_at,
      :categories
    ])
    |> validate_required([:identity_id, :business_name])
    |> validate_length(:business_name, min: 1, max: 200)
    |> validate_length(:description, min: 1, max: 1000)
    |> validate_length(:phone, min: 1, max: 20)
    |> validate_length(:website, min: 1, max: 500)
    |> validate_website_protocol()
    |> validate_length(:address, min: 1, max: 500)
    |> validate_length(:logo_url, min: 1, max: 500)
    |> unique_constraint(:identity_id,
      name: :providers_identity_id_index,
      message: "Provider profile already exists for this identity"
    )
  end

  defp validate_website_protocol(changeset) do
    case get_change(changeset, :website) do
      nil ->
        changeset

      website when is_binary(website) ->
        if String.starts_with?(website, "https://") do
          changeset
        else
          add_error(changeset, :website, "must start with https://")
        end

      _ ->
        changeset
    end
  end
end
