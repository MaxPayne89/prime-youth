defmodule KlassHeroWeb.Schemas.ContactForm do
  @moduledoc """
  Embedded schema for contact form validation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @required_fields [:name, :email, :subject, :message]
  @valid_subjects ~w(general program booking instructor technical other)

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :subject, :string
    field :message, :string
  end

  def changeset(contact_form \\ %__MODULE__{}, attrs) do
    contact_form
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/@/, message: "must be a valid email address")
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:message, min: 10, max: 1000)
    |> validate_inclusion(:subject, @valid_subjects)
  end
end
