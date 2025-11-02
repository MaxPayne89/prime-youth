defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Provider do
  @moduledoc """
  Ecto schema for Provider entity persistence.

  This is a minimal stub schema to satisfy Program associations.
  Full implementation will be completed in User Story 2 (Provider Management).

  ## Associations

  - `has_many :programs` - Programs offered by this provider
  - `belongs_to :user` - Associated user account (from Accounts context)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "providers" do
    field :name, :string
    field :description, :string
    field :email, :string
    field :phone, :string
    field :website, :string
    field :credentials, :string
    field :logo_url, :string
    field :is_verified, :boolean, default: false
    field :is_prime_youth, :boolean, default: false

    # Association to Accounts context (cross-context reference)
    field :user_id, :binary_id

    # Programs offered by this provider (within ProgramCatalog context)
    has_many :programs, PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program

    timestamps(type: :utc_datetime)
  end

  @doc """
  Basic changeset for provider validation.

  Full implementation will be added in User Story 2.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :name,
      :description,
      :email,
      :phone,
      :website,
      :credentials,
      :logo_url,
      :is_verified,
      :is_prime_youth,
      :user_id
    ])
    |> validate_required([:name, :email, :user_id])
    |> validate_length(:name, min: 2, max: 200)
    |> validate_format(:email, ~r/@/)
  end
end
