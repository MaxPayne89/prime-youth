defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema do
  @moduledoc """
  Ecto schema for the provider_session_stats read model table.

  Write-only from the projection's perspective, read-only from the repository's.
  No user-facing changesets — the projection controls all writes.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "provider_session_stats" do
    field :provider_id, :binary_id
    field :program_id, :binary_id
    field :program_title, :string
    field :sessions_completed_count, :integer, default: 0

    timestamps()
  end
end
