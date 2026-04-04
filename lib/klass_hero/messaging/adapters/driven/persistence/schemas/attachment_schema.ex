defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema do
  @moduledoc """
  Ecto schema for message attachments.

  Attachments are immutable — once created, they are never updated.
  Deletion is handled by ON DELETE CASCADE from the messages table.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "message_attachments" do
    field :file_url, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size_bytes, :integer

    belongs_to :message, MessageSchema

    timestamps()
  end

  @required_fields ~w(message_id file_url original_filename content_type file_size_bytes)a

  @doc "Changeset for creating a new attachment."
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:message_id)
  end
end
