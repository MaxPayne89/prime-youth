defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema do
  @moduledoc """
  Ecto schema for the inbound_emails table.

  Use InboundEmailMapper to convert between schema and domain InboundEmail entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(unread read archived)

  schema "inbound_emails" do
    field :resend_id, :string
    field :from_address, :string
    field :from_name, :string
    field :to_addresses, {:array, :string}, default: []
    field :cc_addresses, {:array, :string}, default: []
    field :subject, :string
    field :body_html, :string
    field :body_text, :string
    field :headers, {:array, :map}, default: []
    field :status, :string, default: "unread"
    field :read_by_id, :binary_id
    field :read_at, :utc_datetime_usec
    field :received_at, :utc_datetime_usec

    belongs_to :read_by, User, foreign_key: :read_by_id, define_field: false

    timestamps()
  end

  @required_fields ~w(resend_id from_address to_addresses subject received_at)a
  @optional_fields ~w(from_name cc_addresses body_html body_text headers status)a

  @doc """
  Creates a changeset for new inbound email creation.
  """
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:resend_id)
    |> foreign_key_constraint(:read_by_id)
  end

  @doc """
  Creates a changeset for updating email status.
  """
  def status_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:status, :read_by_id, :read_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
