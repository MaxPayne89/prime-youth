defmodule KlassHero.Support.Domain.Models.ContactForm do
  @moduledoc """
  Embedded schema for contact form validation.

  Provides structured validation for contact form submissions with proper
  error messages and type safety.
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

  @doc """
  Creates a changeset for contact form validation.

  ## Validations

  - All fields required
  - Email must contain @ symbol
  - Name: 2-100 characters
  - Message: 10-1000 characters
  - Subject: must be one of #{inspect(@valid_subjects)}
  """
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
