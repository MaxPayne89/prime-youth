defmodule PrimeYouth.Activities.Domain.Models.Activity do
  @moduledoc """
  Domain model representing an activity in the Activities context.

  This is a pure domain entity representing upcoming activity information
  without any infrastructure concerns. The struct enforces required fields
  and provides a clean interface for the application layer.

  ## Architecture

  This follows the Domain Layer pattern in DDD/Ports & Adapters:
  - Pure Elixir struct with no dependencies on infrastructure
  - Enforces required fields through @enforce_keys
  - Represents the domain concept of a scheduled activity

  ## Fields

  **Required:**
  - `id` - Unique identifier for the activity
  - `status` - Activity status (e.g., "upcoming", "in-progress", "completed")
  - `time` - Activity time or time range
  - `name` - Activity name or title
  - `instructor` - Name of the instructor leading the activity

  **Optional:**
  - `status_color` - Visual color indicator for the status
  """

  @enforce_keys [:id, :status, :time, :name, :instructor]
  defstruct [:id, :status, :status_color, :time, :name, :instructor]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          status: String.t(),
          status_color: String.t() | nil,
          time: String.t(),
          name: String.t(),
          instructor: String.t()
        }
end
