defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema do
  @moduledoc """
  Ecto schema for the program_listings read model table.

  This schema is write-only from the projection's perspective and
  read-only from the repository's perspective. No changesets for
  user-facing validation — the projection controls all writes.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "program_listings" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :age_range, :string
    field :price, :decimal
    field :pricing_period, :string
    field :location, :string
    field :cover_image_url, :string
    field :instructor_name, :string
    field :instructor_headshot_url, :string
    field :start_date, :date
    field :end_date, :date
    field :meeting_days, {:array, :string}, default: []
    field :meeting_start_time, :time
    field :meeting_end_time, :time
    field :season, :string
    field :registration_start_date, :date
    field :registration_end_date, :date
    field :provider_id, :binary_id
    field :provider_verified, :boolean, default: false

    timestamps()
  end
end
