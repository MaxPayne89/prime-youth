defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EmailReplySchema do
  @moduledoc """
  Ecto schema for the email_replies table.

  Use EmailReplyMapper to convert between schema and domain EmailReply entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Accounts.User
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(sending sent failed)

  schema "email_replies" do
    field :body, :string
    field :status, :string, default: "sending"
    field :resend_message_id, :string
    field :sent_at, :utc_datetime_usec
    field :inbound_email_id, :binary_id
    field :sent_by_id, :binary_id

    belongs_to :inbound_email, InboundEmailSchema,
      foreign_key: :inbound_email_id,
      define_field: false

    belongs_to :sent_by, User,
      foreign_key: :sent_by_id,
      define_field: false

    timestamps()
  end

  @required_fields ~w(inbound_email_id body sent_by_id)a
  @optional_fields ~w(status resend_message_id sent_at)a

  @doc """
  Creates a changeset for new email reply creation.
  """
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:inbound_email_id)
    |> foreign_key_constraint(:sent_by_id)
  end

  @doc """
  Creates a changeset for updating email reply status.
  """
  def status_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:status, :resend_message_id, :sent_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
