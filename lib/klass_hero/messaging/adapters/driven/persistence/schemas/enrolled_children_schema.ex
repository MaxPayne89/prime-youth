defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema do
  @moduledoc """
  Ecto schema for the messaging_enrolled_children projection table.

  Write-only from the EnrolledChildren projection's perspective.
  Read-only for handlers that need to derive child names for conversations.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "messaging_enrolled_children" do
    field :parent_user_id, :binary_id
    field :program_id, :binary_id
    field :child_id, :binary_id
    field :child_first_name, :string

    timestamps()
  end
end
