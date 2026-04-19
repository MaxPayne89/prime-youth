defmodule KlassHero.Provider.Domain.ReadModels.SessionStats do
  @moduledoc """
  Read-optimized DTO for provider session statistics.

  Lightweight struct for display — no business logic, no value objects.
  Populated from the denormalized provider_session_stats read table.
  """

  @typedoc "A denormalized session stats record for display in the provider dashboard."
  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t(),
          program_id: String.t(),
          program_title: String.t(),
          sessions_completed_count: non_neg_integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:id, :provider_id, :program_id, :program_title, :sessions_completed_count]

  defstruct [
    :id,
    :provider_id,
    :program_id,
    :program_title,
    :inserted_at,
    :updated_at,
    sessions_completed_count: 0
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end
end
