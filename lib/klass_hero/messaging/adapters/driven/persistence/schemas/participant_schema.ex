defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema do
  @moduledoc """
  Ecto schema for the conversation_participants table.

  Use ParticipantMapper to convert between schema and domain Participant entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Accounts.User
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "conversation_participants" do
    field :conversation_id, :binary_id
    field :user_id, :binary_id
    field :last_read_at, :utc_datetime
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime

    belongs_to :conversation, ConversationSchema, define_field: false
    belongs_to :user, User, define_field: false

    timestamps()
  end

  @required_fields ~w(conversation_id user_id joined_at)a
  @optional_fields ~w(last_read_at left_at)a

  @doc """
  Creates a changeset for adding a participant.
  """
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:conversation_id, :user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for marking messages as read.
  """
  def mark_read_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:last_read_at])
    |> validate_required([:last_read_at])
  end

  @doc """
  Creates a changeset for leaving a conversation.
  """
  def leave_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:left_at])
    |> validate_required([:left_at])
  end
end
