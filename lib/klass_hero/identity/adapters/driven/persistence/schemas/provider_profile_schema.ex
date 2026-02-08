defmodule KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema do
  @moduledoc """
  Ecto schema for the providers table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use ProviderProfileMapper to convert between ProviderProfileSchema and domain ProviderProfile entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Accounts.User

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
    field :subscription_tier, :string, default: "starter"

    belongs_to :verified_by, User, type: :binary_id

    timestamps()
  end

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
  - subscription_tier (must be "starter", "professional", or "business_plus", defaults to "starter")
  """
  def changeset(provider_profile_schema, attrs) do
    provider_profile_schema
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
      :verified_by_id,
      :categories,
      :subscription_tier
    ])
    |> validate_required([:identity_id, :business_name])
    |> validate_length(:business_name, min: 1, max: 200)
    |> validate_length(:description, min: 1, max: 1000)
    |> validate_length(:phone, min: 1, max: 20)
    |> validate_length(:website, min: 1, max: 500)
    |> validate_website_protocol()
    |> validate_length(:address, min: 1, max: 500)
    |> validate_length(:logo_url, min: 1, max: 500)
    |> validate_inclusion(:subscription_tier, ["starter", "professional", "business_plus"])
    |> unique_constraint(:identity_id,
      name: :providers_identity_id_index,
      message: "Provider profile already exists for this identity"
    )
  end

  @doc """
  Form changeset for provider profile editing via LiveView.

  Only casts `:description` — logo_url is set programmatically after upload,
  and other fields (business_name, phone, etc.) are not editable in this form.
  """
  def edit_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:description])
    |> validate_length(:description, max: 1000)
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
