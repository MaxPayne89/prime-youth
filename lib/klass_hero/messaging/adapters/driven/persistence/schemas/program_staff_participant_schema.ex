defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ProgramStaffParticipantSchema do
  @moduledoc """
  Ecto schema for the program_staff_participants projection table.

  This schema is a read model owned by the Messaging bounded context,
  populated by integration events from the Provider context. The source
  of truth is the program_staff_assignments table in the Provider context.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  schema "program_staff_participants" do
    field :provider_id, :binary_id
    field :program_id, :binary_id
    field :staff_user_id, :binary_id
    field :active, :boolean, default: true

    timestamps()
  end

  @required_fields ~w(provider_id program_id staff_user_id)a
  @optional_fields ~w(active)a

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:program_id, :staff_user_id])
  end
end
