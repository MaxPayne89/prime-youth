defmodule KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing do
  @moduledoc """
  Read-optimized DTO for program listings.

  Lightweight struct for display — no business logic, no value objects.
  Populated from the denormalized program_listings read table.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t() | nil,
          category: String.t() | nil,
          age_range: String.t() | nil,
          price: Decimal.t() | nil,
          pricing_period: String.t() | nil,
          location: String.t() | nil,
          cover_image_url: String.t() | nil,
          icon_path: String.t() | nil,
          instructor_name: String.t() | nil,
          instructor_headshot_url: String.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          meeting_days: [String.t()],
          meeting_start_time: Time.t() | nil,
          meeting_end_time: Time.t() | nil,
          season: String.t() | nil,
          registration_start_date: Date.t() | nil,
          registration_end_date: Date.t() | nil,
          provider_id: String.t(),
          provider_verified: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:id, :title, :provider_id]

  defstruct [
    :id,
    :title,
    :description,
    :category,
    :age_range,
    :price,
    :pricing_period,
    :location,
    :cover_image_url,
    :icon_path,
    :instructor_name,
    :instructor_headshot_url,
    :start_date,
    :end_date,
    :meeting_start_time,
    :meeting_end_time,
    :season,
    :registration_start_date,
    :registration_end_date,
    :provider_id,
    :inserted_at,
    :updated_at,
    meeting_days: [],
    provider_verified: false
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end
end
